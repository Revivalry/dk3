/*
===========================================================================
ioquake3 png decoder
Copyright (C) 2007,2008 Joerg Dietrich

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
===========================================================================
*/

#include "tr_common.h"

#include "../thirdparty/zlib-1.3.1/zlib.h"
#include "../thirdparty/libdeflate-1.26/libdeflate.h"
#if defined(__SSE2__)
#include <emmintrin.h>
#if defined(__GNUC__) && defined(__x86_64__)
#define PNG_RUNTIME_SSE41 1
#include <cpuid.h>
#include <smmintrin.h>
#endif
#endif

// we could limit the png size to a lower value here
#ifndef INT_MAX
#define INT_MAX 0x1fffffff
#endif

/*
=================
PNG LOADING
=================
*/

/*
 *  Quake 3 image format : RGBA
 */

#define Q3IMAGE_BYTESPERPIXEL (4)

/*
 *  PNG specifications
 */

/*
 *  The first 8 Bytes of every PNG-File are a fixed signature
 *  to identify the file as a PNG.
 */

#define PNG_Signature "\x89\x50\x4E\x47\xD\xA\x1A\xA"
#define PNG_Signature_Size (8)

/*
 *  After the signature diverse chunks follow.
 *  A chunk consists of a header and if Length
 *  is bigger than 0 a body and a CRC of the body follow.
 */

struct PNG_ChunkHeader
{
	uint32_t Length;
	uint32_t Type;
};

#define PNG_ChunkHeader_Size (8)

typedef uint32_t PNG_ChunkCRC;

#define PNG_ChunkCRC_Size (4)

/*
 *  We use the following ChunkTypes.
 *  All others are ignored.
 */

#define MAKE_CHUNKTYPE(a,b,c,d) (((a) << 24) | ((b) << 16) | ((c) << 8) | ((d)))

#define PNG_ChunkType_IHDR MAKE_CHUNKTYPE('I', 'H', 'D', 'R')
#define PNG_ChunkType_PLTE MAKE_CHUNKTYPE('P', 'L', 'T', 'E')
#define PNG_ChunkType_IDAT MAKE_CHUNKTYPE('I', 'D', 'A', 'T')
#define PNG_ChunkType_IEND MAKE_CHUNKTYPE('I', 'E', 'N', 'D')
#define PNG_ChunkType_tRNS MAKE_CHUNKTYPE('t', 'R', 'N', 'S')

/*
 *  Per specification the first chunk after the signature SHALL be IHDR.
 */

struct PNG_Chunk_IHDR
{
	uint32_t Width;
	uint32_t Height;
	uint8_t  BitDepth;
	uint8_t  ColourType;
	uint8_t  CompressionMethod;
	uint8_t  FilterMethod;
	uint8_t  InterlaceMethod;
};

#define PNG_Chunk_IHDR_Size (13)

/*
 *  ColourTypes
 */

#define PNG_ColourType_Grey      (0)
#define PNG_ColourType_True      (2)
#define PNG_ColourType_Indexed   (3)
#define PNG_ColourType_GreyAlpha (4)
#define PNG_ColourType_TrueAlpha (6)

/*
 *  number of colour components
 *
 *  Grey      : 1 grey
 *  True      : 1 R, 1 G, 1 B
 *  Indexed   : 1 index
 *  GreyAlpha : 1 grey, 1 alpha
 *  TrueAlpha : 1 R, 1 G, 1 B, 1 alpha
 */

#define PNG_NumColourComponents_Grey      (1)
#define PNG_NumColourComponents_True      (3)
#define PNG_NumColourComponents_Indexed   (1)
#define PNG_NumColourComponents_GreyAlpha (2)
#define PNG_NumColourComponents_TrueAlpha (4)

/*
 *  For the different ColourTypes
 *  different BitDepths are specified.
 */

#define PNG_BitDepth_1  ( 1)
#define PNG_BitDepth_2  ( 2)
#define PNG_BitDepth_4  ( 4)
#define PNG_BitDepth_8  ( 8)
#define PNG_BitDepth_16 (16)

/*
 *  Only one valid CompressionMethod is standardized.
 */

#define PNG_CompressionMethod_0 (0)

/*
 *  Only one valid FilterMethod is currently standardized.
 */

#define PNG_FilterMethod_0 (0)

/*
 *  This FilterMethod defines 5 FilterTypes
 */

#define PNG_FilterType_None    (0)
#define PNG_FilterType_Sub     (1)
#define PNG_FilterType_Up      (2)
#define PNG_FilterType_Average (3)
#define PNG_FilterType_Paeth   (4)

/*
 *  Two InterlaceMethods are standardized :
 *  0 - NonInterlaced
 *  1 - Interlaced
 */

#define PNG_InterlaceMethod_NonInterlaced (0)
#define PNG_InterlaceMethod_Interlaced    (1)

/*
 *  The Adam7 interlace method uses 7 passes.
 */

#define PNG_Adam7_NumPasses (7)

/*
 *  The compressed data starts with a header ...
 */

struct PNG_ZlibHeader
{
	uint8_t CompressionMethod;
	uint8_t Flags;
};

#define PNG_ZlibHeader_Size (2)

/*
 *  ... and is followed by a check value
 */

#define PNG_ZlibCheckValue_Size (4)

/*
 *  Some support functions for buffered files follow.
 */

/*
 *  buffered file representation
 */

struct BufferedFile
{
	byte *Buffer;
	int   Length;
	byte *Ptr;
	int   BytesLeft;
};

/*
 *  Get a pointer to the requested bytes.
 */

static void *BufferedFileRead(struct BufferedFile *BF, unsigned Length)
{
	void *RetVal;

	/*
	 *  input verification
	 */

	if(!(BF && Length))
	{
		return(NULL);
	}

	/*
	 *  not enough bytes left
	 */

	if(Length > BF->BytesLeft)
	{
		return(NULL);
	}

	/*
	 *  the pointer to the requested data
	 */

	RetVal = BF->Ptr;

	/*
	 *  Raise the pointer and counter.
	 */

	BF->Ptr       += Length;
	BF->BytesLeft -= Length;

	return(RetVal);
}

/*
 *  Rewind the buffer.
 */

static qboolean BufferedFileRewind(struct BufferedFile *BF, unsigned Offset)
{
	unsigned BytesRead; 

	/*
	 *  input verification
	 */

	if(!BF)
	{
		return(qfalse);
	}

	/*
	 *  special trick to rewind to the beginning of the buffer
	 */

	if(Offset == (unsigned)-1)
	{
		BF->Ptr       = BF->Buffer;
		BF->BytesLeft = BF->Length;

		return(qtrue);
	}

	/*
	 *  How many bytes do we have already read?
	 */

	BytesRead = BF->Ptr - BF->Buffer;

	/*
	 *  We can only rewind to the beginning of the BufferedFile.
	 */

	if(Offset > BytesRead)
	{
		return(qfalse);
	}

	/*
	 *  lower the pointer and counter.
	 */

	BF->Ptr       -= Offset;
	BF->BytesLeft += Offset;

	return(qtrue);
}

/*
 *  Skip some bytes.
 */

static qboolean BufferedFileSkip(struct BufferedFile *BF, unsigned Offset)
{
	/*
	 *  input verification
	 */

	if(!BF)
	{
		return(qfalse);
	}

	/*
	 *  We can only skip to the end of the BufferedFile.
	 */

	if(Offset > BF->BytesLeft)
	{
		return(qfalse);
	}

	/*
	 *  lower the pointer and counter.
	 */

	BF->Ptr       += Offset;
	BF->BytesLeft -= Offset;

	return(qtrue);
}

/*
 *  Find a chunk
 */

static qboolean FindChunk(struct BufferedFile *BF, uint32_t ChunkType)
{
	struct PNG_ChunkHeader *CH;

	uint32_t Length;
	uint32_t Type;

	/*
	 *  input verification
	 */

	if(!BF)
	{
		return(qfalse);
	}

	/*
	 *  cycle trough the chunks
	 */

	while(qtrue)
	{
		/*
		 *  Read the chunk-header.
		 */

		CH = BufferedFileRead(BF, PNG_ChunkHeader_Size);
		if(!CH)
		{
			return(qfalse);
		}

		/*
		 *  Do not swap the original types
		 *  they might be needed later.
		 */

		Length = BigLong(CH->Length);
		Type   = BigLong(CH->Type);

		/*
		 *  We found it!
		 */

		if(Type == ChunkType)
		{
			/*
			 *  Rewind to the start of the chunk.
			 */

			BufferedFileRewind(BF, PNG_ChunkHeader_Size);

			break;
		}
		else
		{
			/*
			 *  Skip the rest of the chunk.
			 */

			if(Length)
			{
				if(!BufferedFileSkip(BF, Length + PNG_ChunkCRC_Size))
				{
					return(qfalse);
				}  
			}
		}
	}

	return(qtrue);
}

/* Calculate the exact filtered scanline size before allocating/inflating.
 * PNG's Adam7 pass layout is shared with the existing pixel conversion below.
 * This replaces the former two complete puff() passes for each HD image. */
static uint32_t PNG_FilteredSize(const struct PNG_Chunk_IHDR *header) {
    static const unsigned xoff[7] = {0, 4, 0, 2, 0, 1, 0};
    static const unsigned yoff[7] = {0, 0, 4, 0, 2, 0, 1};
    static const unsigned xstep[7] = {8, 8, 4, 4, 2, 2, 1};
    static const unsigned ystep[7] = {8, 8, 8, 4, 4, 2, 2};
    uint64_t width = (uint32_t)BigLong(header->Width);
    uint64_t height = (uint32_t)BigLong(header->Height), total = 0;
    unsigned components, bits, pass, count;
    switch (header->ColourType) {
    case PNG_ColourType_Grey: components = 1; break;
    case PNG_ColourType_True: components = 3; break;
    case PNG_ColourType_Indexed: components = 1; break;
    case PNG_ColourType_GreyAlpha: components = 2; break;
    case PNG_ColourType_TrueAlpha: components = 4; break;
    default: return 0;
    }
    bits = header->BitDepth;
    if (bits != 1 && bits != 2 && bits != 4 && bits != 8 && bits != 16) return 0;
    if ((header->ColourType == PNG_ColourType_Indexed && bits == 16) ||
        (components > 1 && bits < 8)) return 0;
    bits *= components;
    count = header->InterlaceMethod == PNG_InterlaceMethod_Interlaced ? 7 : 1;
    for (pass = 0; pass < count; ++pass) {
        uint64_t w = width, h = height;
        if (count == 7) {
            w = width > xoff[pass] ? (width - xoff[pass] + xstep[pass] - 1) / xstep[pass] : 0;
            h = height > yoff[pass] ? (height - yoff[pass] + ystep[pass] - 1) / ystep[pass] : 0;
        }
        if (w && h) total += (((w * bits + 7) / 8) + 1) * h;
    }
    return total && total <= INT_MAX ? (uint32_t)total : 0;
}

/* Validate consecutive IDAT chunks, then inflate once into the exact bound.
 * dk3 alteration: the pinned full-buffer decoder validates the header/checksum. No GL,
 * filesystem or renderer state is accessed by the inflater. */
static uint32_t DecompressIDATs(struct BufferedFile *BF, uint8_t **Buffer, uint32_t expected) {
    uint8_t *compressed, *output, *start;
    unsigned left, length, total = 0, chunks = 0;
    struct PNG_ChunkHeader *chunk;
    struct libdeflate_decompressor *decoder;
    size_t consumed = 0, written = 0;
    int result;
    *Buffer = NULL;
    if (!expected || !FindChunk(BF, PNG_ChunkType_IDAT)) return 0;
    start = BF->Ptr;
    left = BF->BytesLeft;
    for (;;) {
        chunk = BufferedFileRead(BF, PNG_ChunkHeader_Size);
        if (!chunk) return 0;
        if ((uint32_t)BigLong(chunk->Type) != PNG_ChunkType_IDAT) {
            BufferedFileRewind(BF, PNG_ChunkHeader_Size);
            break;
        }
        length = (uint32_t)BigLong(chunk->Length);
        if (length > BF->BytesLeft || BF->BytesLeft - length < PNG_ChunkCRC_Size ||
            length > INT_MAX - total) return 0;
        total += length;
        ++chunks;
        /* Even an empty IDAT has a CRC. */
        if (!BufferedFileSkip(BF, length + PNG_ChunkCRC_Size)) return 0;
    }
    if (!total) return 0;
    if (chunks == 1) {
        /* The validated IDAT already is contiguous immutable input. Keep its
         * owner alive through inflate instead of copying large RGB textures. */
        compressed = start + PNG_ChunkHeader_Size;
    } else {
        compressed = malloc(total);
        if (!compressed) return 0;
        BF->Ptr = start;
        BF->BytesLeft = left;
        total = 0;
        for (;;) {
            chunk = BufferedFileRead(BF, PNG_ChunkHeader_Size);
            if ((uint32_t)BigLong(chunk->Type) != PNG_ChunkType_IDAT) {
                BufferedFileRewind(BF, PNG_ChunkHeader_Size);
                break;
            }
            length = (uint32_t)BigLong(chunk->Length);
            if (length) memcpy(compressed + total, BufferedFileRead(BF, length), length);
            total += length;
            BufferedFileSkip(BF, PNG_ChunkCRC_Size);
        }
    }
    output = malloc(expected);
    if (!output) { if (chunks != 1) free(compressed); return 0; }
    decoder = libdeflate_alloc_decompressor();
    if (!decoder) { if (chunks != 1) free(compressed); free(output); return 0; }
    result = libdeflate_zlib_decompress_ex(decoder, compressed, total, output,
                                         expected, &consumed, &written);
    libdeflate_free_decompressor(decoder);
    if (chunks != 1) free(compressed);
    if (result != LIBDEFLATE_SUCCESS || consumed != total || written != expected) { free(output); return 0; }
    *Buffer = output;
    return expected;
}

/*
 *  the Paeth predictor
 */

static uint8_t PredictPaeth(uint8_t a, uint8_t b, uint8_t c)
{
	/*
	 *  a == Left
	 *  b == Up
	 *  c == UpLeft
	 */

	uint8_t Pr;
	int p;
	int pa, pb, pc;

	p  = ((int) a) + ((int) b) - ((int) c);
	pa = abs(p - ((int) a));
	pb = abs(p - ((int) b));
	pc = abs(p - ((int) c));

	if((pa <= pb) && (pa <= pc))
	{
		Pr = a;
	}
	else if(pb <= pc)
	{
		Pr = b;
	}
	else
	{
		Pr = c;
	}

	return(Pr);

}

/*
 *  Reverse the filters.
 */

/* Dispatch once per scanline: its filter is constant across all bytes.
 * The first bpp bytes have no left neighbour. First-row Paeth reduces to Sub. */
#if defined(__SSE2__)
static __m128i PNG_Channels4(const uint8_t *bytes) {
    uint32_t packed;
    memcpy(&packed, bytes, 4);
    return _mm_unpacklo_epi8(_mm_cvtsi32_si128(packed), _mm_setzero_si128());
}
static __m128i PNG_Abs16(__m128i value) {
    __m128i sign = _mm_srai_epi16(value, 15);
    return _mm_sub_epi16(_mm_xor_si128(value, sign), sign);
}
/* Pixels depend on the pixel to their left, but the four byte channels are
 * independent. Signed 16-bit lanes cover every Paeth distance (-510..510).
 * Comparisons retain the specification's left, above, upper-left tie order. */
static void PNG_Paeth4(uint8_t *row, const uint8_t *above, uint32_t size) {
    __m128i a = PNG_Channels4(row), c = PNG_Channels4(above);
    const __m128i mask = _mm_set1_epi16(255);
    uint32_t x;
    for (x = 4; x < size; x += 4) {
        __m128i b = PNG_Channels4(above + x);
        __m128i pa = PNG_Abs16(_mm_sub_epi16(b, c));
        __m128i pb = PNG_Abs16(_mm_sub_epi16(a, c));
        __m128i pc = PNG_Abs16(_mm_sub_epi16(_mm_add_epi16(a, b), _mm_add_epi16(c, c)));
        __m128i reject_a = _mm_or_si128(_mm_cmpgt_epi16(pa, pb), _mm_cmpgt_epi16(pa, pc));
        __m128i reject_b = _mm_cmpgt_epi16(pb, pc);
        __m128i bc = _mm_or_si128(_mm_andnot_si128(reject_b, b), _mm_and_si128(reject_b, c));
        __m128i predictor = _mm_or_si128(_mm_andnot_si128(reject_a, a), _mm_and_si128(reject_a, bc));
        uint32_t packed;
        a = _mm_and_si128(_mm_add_epi16(PNG_Channels4(row + x), predictor), mask);
        packed = _mm_cvtsi128_si32(_mm_packus_epi16(a, _mm_setzero_si128()));
        memcpy(row + x, &packed, 4);
        c = b;
    }
}
#if defined(PNG_RUNTIME_SSE41)
/* dk3 alteration: keep the portable path, selecting newer instructions only
 * after CPUID. No mutable dispatch state is shared between decoder workers. */
static qboolean PNG_CanPaeth41(void) {
    unsigned a, b, c, d;
    const unsigned required = bit_SSE3 | bit_SSSE3 | bit_SSE4_1;
    return __get_cpuid(1, &a, &b, &c, &d) && (c & required) == required;
}
__attribute__((target("sse4.1"), noinline))
static void PNG_Paeth4SSE41(uint8_t *row, const uint8_t *above, uint32_t size) {
    __m128i a = PNG_Channels4(row), c = PNG_Channels4(above);
    const __m128i mask = _mm_set1_epi16(255);
    uint32_t x;
    for (x = 4; x < size; x += 4) {
        __m128i b = PNG_Channels4(above + x);
        __m128i pa = _mm_abs_epi16(_mm_sub_epi16(b, c));
        __m128i pb = _mm_abs_epi16(_mm_sub_epi16(a, c));
        __m128i pc = _mm_abs_epi16(_mm_sub_epi16(_mm_add_epi16(a, b), _mm_add_epi16(c, c)));
        __m128i reject_a = _mm_or_si128(_mm_cmpgt_epi16(pa, pb), _mm_cmpgt_epi16(pa, pc));
        __m128i reject_b = _mm_cmpgt_epi16(pb, pc);
        __m128i predictor = _mm_blendv_epi8(a, _mm_blendv_epi8(b, c, reject_b), reject_a);
        uint32_t packed;
        a = _mm_and_si128(_mm_add_epi16(PNG_Channels4(row + x), predictor), mask);
        packed = _mm_cvtsi128_si32(_mm_packus_epi16(a, _mm_setzero_si128()));
        memcpy(row + x, &packed, 4);
        c = b;
    }
}
#endif
#endif

static qboolean UnfilterImage(uint8_t *data, uint32_t height,
                              uint32_t rowBytes, uint32_t bpp)
{
    uint32_t y, x, leading;
    uint8_t *row = data;
    if (!data || !bpp) return qfalse;
    if (!height || !rowBytes) return qtrue;
#if defined(PNG_RUNTIME_SSE41)
    const qboolean paeth41 = bpp == 4 && rowBytes >= 4 && !(rowBytes & 3) && PNG_CanPaeth41();
#endif
    leading = bpp < rowBytes ? bpp : rowBytes;
    for (y = 0; y < height; ++y) {
        uint8_t filter = *row++;
        const uint8_t *above = y ? row - rowBytes - 1 : NULL;
        switch (filter) {
        case PNG_FilterType_None:
            break;
        case PNG_FilterType_Sub:
            for (x = bpp; x < rowBytes; ++x) row[x] += row[x - bpp];
            break;
        case PNG_FilterType_Up:
            if (above) for (x = 0; x < rowBytes; ++x) row[x] += above[x];
            break;
        case PNG_FilterType_Average:
            if (above) {
                for (x = 0; x < leading; ++x) row[x] += above[x] >> 1;
                for (x = bpp; x < rowBytes; ++x)
                    row[x] += ((unsigned)row[x - bpp] + above[x]) >> 1;
            } else {
                for (x = bpp; x < rowBytes; ++x) row[x] += row[x - bpp] >> 1;
            }
            break;
        case PNG_FilterType_Paeth:
            if (above) {
                for (x = 0; x < leading; ++x) row[x] += above[x];
#if defined(__SSE2__)
                if (bpp == 4 && rowBytes >= 4 && !(rowBytes & 3)) {
#if defined(PNG_RUNTIME_SSE41)
                    if (paeth41) PNG_Paeth4SSE41(row, above, rowBytes);
                    else
#endif
                    PNG_Paeth4(row, above, rowBytes);
                    break;
                }
#endif
                for (x = bpp; x < rowBytes; ++x)
                    row[x] += PredictPaeth(row[x - bpp], above[x], above[x - bpp]);
            } else {
                for (x = bpp; x < rowBytes; ++x) row[x] += row[x - bpp];
            }
            break;
        default:
            return qfalse;
        }
        row += rowBytes;
    }
    return qtrue;
}

/*
 *  Convert a raw input pixel to Quake 3 RGA format.
 */

static qboolean ConvertPixel(struct PNG_Chunk_IHDR *IHDR,
		byte                  *OutPtr,
		uint8_t               *DecompPtr,
		qboolean               HasTransparentColour,
		uint8_t               *TransparentColour,
		uint8_t               *OutPal)
{
	/*
	 *  input verification
	 */

	if(!(IHDR && OutPtr && DecompPtr && TransparentColour && OutPal))
	{
		return(qfalse);
	}

	switch(IHDR->ColourType)
	{
		case PNG_ColourType_Grey :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_1 :
				case PNG_BitDepth_2 :
				case PNG_BitDepth_4 :
				{
					uint8_t Step;
					uint8_t GreyValue;

					Step = 0xFF / ((1 << IHDR->BitDepth) - 1);

					GreyValue = DecompPtr[0] * Step;

					OutPtr[0] = GreyValue;
					OutPtr[1] = GreyValue;
					OutPtr[2] = GreyValue;
					OutPtr[3] = 0xFF;

					/*
					 *  Grey supports full transparency for one specified colour
					 */

					if(HasTransparentColour)
					{
						if(TransparentColour[1] == DecompPtr[0])
						{
							OutPtr[3] = 0x00;
						}
					}


					break;
				}

				case PNG_BitDepth_8 :
				case PNG_BitDepth_16 :
				{
					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[0];
					OutPtr[2] = DecompPtr[0];
					OutPtr[3] = 0xFF;

					/*
					 *  Grey supports full transparency for one specified colour
					 */

					if(HasTransparentColour)
					{
						if(IHDR->BitDepth == PNG_BitDepth_8)
						{
							if(TransparentColour[1] == DecompPtr[0])
							{
								OutPtr[3] = 0x00;
							}
						}
						else
						{
							if((TransparentColour[0] == DecompPtr[0]) && (TransparentColour[1] == DecompPtr[1]))
							{
								OutPtr[3] = 0x00;
							}
						}
					}

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_True :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				{
					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[1];
					OutPtr[2] = DecompPtr[2];
					OutPtr[3] = 0xFF;

					/*
					 *  True supports full transparency for one specified colour
					 */

					if(HasTransparentColour)
					{
						if((TransparentColour[1] == DecompPtr[0]) &&
								(TransparentColour[3] == DecompPtr[1]) &&
								(TransparentColour[5] == DecompPtr[2]))
						{
							OutPtr[3] = 0x00;
						}
					}

					break;
				}

				case PNG_BitDepth_16 :
				{
					/*
					 *  We use only the upper byte.
					 */

					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[2];
					OutPtr[2] = DecompPtr[4];
					OutPtr[3] = 0xFF;

					/*
					 *  True supports full transparency for one specified colour
					 */

					if(HasTransparentColour)
					{
						if((TransparentColour[0] == DecompPtr[0]) && (TransparentColour[1] == DecompPtr[1]) &&
								(TransparentColour[2] == DecompPtr[2]) && (TransparentColour[3] == DecompPtr[3]) &&
								(TransparentColour[4] == DecompPtr[4]) && (TransparentColour[5] == DecompPtr[5]))
						{
							OutPtr[3] = 0x00;
						}
					}

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_Indexed :
		{
			OutPtr[0] = OutPal[DecompPtr[0] * Q3IMAGE_BYTESPERPIXEL + 0];
			OutPtr[1] = OutPal[DecompPtr[0] * Q3IMAGE_BYTESPERPIXEL + 1];
			OutPtr[2] = OutPal[DecompPtr[0] * Q3IMAGE_BYTESPERPIXEL + 2];
			OutPtr[3] = OutPal[DecompPtr[0] * Q3IMAGE_BYTESPERPIXEL + 3];

			break;
		}

		case PNG_ColourType_GreyAlpha :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				{
					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[0];
					OutPtr[2] = DecompPtr[0];
					OutPtr[3] = DecompPtr[1];

					break;
				}

				case PNG_BitDepth_16 :
				{
					/*
					 *  We use only the upper byte.
					 */

					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[0];
					OutPtr[2] = DecompPtr[0];
					OutPtr[3] = DecompPtr[2];

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_TrueAlpha :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				{
					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[1];
					OutPtr[2] = DecompPtr[2];
					OutPtr[3] = DecompPtr[3];

					break;
				}

				case PNG_BitDepth_16 :
				{
					/*
					 *  We use only the upper byte.
					 */

					OutPtr[0] = DecompPtr[0];
					OutPtr[1] = DecompPtr[2];
					OutPtr[2] = DecompPtr[4];
					OutPtr[3] = DecompPtr[6];

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		default :
		{
			return(qfalse);
		}
	}

	return(qtrue);
}


/*
 *  Decode a non-interlaced image.
 */

static qboolean DecodeImageNonInterlaced(struct PNG_Chunk_IHDR *IHDR,
		byte                  *OutBuffer, 
		uint8_t               *DecompressedData,
		uint32_t               DecompressedDataLength,
		qboolean               HasTransparentColour,
		uint8_t               *TransparentColour,
		uint8_t               *OutPal)
{
	uint32_t IHDR_Width;
	uint32_t IHDR_Height;
	uint32_t BytesPerScanline, BytesPerPixel, PixelsPerByte;
	uint32_t  w, h, p;
	byte *OutPtr;
	uint8_t *DecompPtr;

	/*
	 *  input verification
	 */

	if(!(IHDR && OutBuffer && DecompressedData && DecompressedDataLength && TransparentColour && OutPal))
	{
		return(qfalse);
	}

	/*
	 *  byte swapping
	 */

	IHDR_Width  = BigLong(IHDR->Width);
	IHDR_Height = BigLong(IHDR->Height);

	/*
	 *  information for un-filtering
	 */

	switch(IHDR->ColourType)
	{
		case PNG_ColourType_Grey :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_1 :
				case PNG_BitDepth_2 :
				case PNG_BitDepth_4 :
				{
					BytesPerPixel    = 1;
					PixelsPerByte    = 8 / IHDR->BitDepth;

					break;
				}

				case PNG_BitDepth_8  :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_Grey;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_True :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8  :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_True;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_Indexed :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_1 :
				case PNG_BitDepth_2 :
				case PNG_BitDepth_4 :
				{
					BytesPerPixel    = 1;
					PixelsPerByte    = 8 / IHDR->BitDepth;

					break;
				}

				case PNG_BitDepth_8 :
				{
					BytesPerPixel    = PNG_NumColourComponents_Indexed;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_GreyAlpha :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_GreyAlpha;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_TrueAlpha :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_TrueAlpha;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		default :
		{
			return(qfalse);
		}
	}

	/*
	 *  Calculate the size of one scanline
	 */

	BytesPerScanline = (IHDR_Width * BytesPerPixel + (PixelsPerByte - 1)) / PixelsPerByte;

	/*
	 *  Check if we have enough data for the whole image.
	 */

	if(!(DecompressedDataLength == ((BytesPerScanline + 1) * IHDR_Height)))
	{
		return(qfalse);
	}

	/*
	 *  Unfilter the image.
	 */

	if(!UnfilterImage(DecompressedData, IHDR_Height, BytesPerScanline, BytesPerPixel))
	{
		return(qfalse);
	}

	/*
	 *  Set the working pointers to the beginning of the buffers.
	 */

	OutPtr = OutBuffer;
	DecompPtr = DecompressedData;

    /* Common 8-bit true-colour rows have a constant conversion contract. */
    if (IHDR->BitDepth == PNG_BitDepth_8 && IHDR->ColourType == PNG_ColourType_TrueAlpha) {
        for (h = 0; h < IHDR_Height; ++h) {
            memcpy(OutPtr, DecompPtr + 1, BytesPerScanline);
            OutPtr += BytesPerScanline;
            DecompPtr += BytesPerScanline + 1;
        }
        return qtrue;
    }
    if (IHDR->BitDepth == PNG_BitDepth_8 && IHDR->ColourType == PNG_ColourType_True && !HasTransparentColour) {
        for (h = 0; h < IHDR_Height; ++h) {
            const uint8_t *source = DecompPtr + 1;
            for (w = 0; w < IHDR_Width; ++w) {
                OutPtr[0] = source[0]; OutPtr[1] = source[1]; OutPtr[2] = source[2]; OutPtr[3] = 255;
                OutPtr += 4;
                source += 3;
            }
            DecompPtr += BytesPerScanline + 1;
        }
        return qtrue;
    }

	/*
	 *  Create the output image.
	 */

	for(h = 0; h < IHDR_Height; h++)
	{
		/*
		 *  Count the pixels on the scanline for those multipixel bytes
		 */

		uint32_t CurrPixel;

		/*
		 *  skip FilterType
		 */

		DecompPtr++;

		/*
		 *  Reset the pixel count.
		 */

		CurrPixel = 0;

		for(w = 0; w < (BytesPerScanline / BytesPerPixel); w++)
		{
			if(PixelsPerByte > 1)
			{
				uint8_t  Mask;
				uint32_t Shift;
				uint8_t  SinglePixel;

				for(p = 0; p < PixelsPerByte; p++)
				{
					if(CurrPixel < IHDR_Width)
					{
						Mask  = (1 << IHDR->BitDepth) - 1;
						Shift = (PixelsPerByte - 1 - p) * IHDR->BitDepth;

						SinglePixel = ((DecompPtr[0] & (Mask << Shift)) >> Shift);

						if(!ConvertPixel(IHDR, OutPtr, &SinglePixel, HasTransparentColour, TransparentColour, OutPal))
						{
							return(qfalse);
						}

						OutPtr += Q3IMAGE_BYTESPERPIXEL;
						CurrPixel++;
					}
				}

			}
			else
			{
				if(!ConvertPixel(IHDR, OutPtr, DecompPtr, HasTransparentColour, TransparentColour, OutPal))
				{
					return(qfalse);
				}


				OutPtr += Q3IMAGE_BYTESPERPIXEL;
			}

			DecompPtr += BytesPerPixel;
		}
	}

	return(qtrue);
}

/*
 *  Decode an interlaced image.
 */

static qboolean DecodeImageInterlaced(struct PNG_Chunk_IHDR *IHDR,
		byte                  *OutBuffer, 
		uint8_t               *DecompressedData,
		uint32_t               DecompressedDataLength,
		qboolean               HasTransparentColour,
		uint8_t               *TransparentColour,
		uint8_t               *OutPal)
{
	uint32_t IHDR_Width;
	uint32_t IHDR_Height;
	uint32_t BytesPerScanline[PNG_Adam7_NumPasses], BytesPerPixel, PixelsPerByte;
	uint32_t PassWidth[PNG_Adam7_NumPasses], PassHeight[PNG_Adam7_NumPasses];
	uint32_t WSkip[PNG_Adam7_NumPasses], WOffset[PNG_Adam7_NumPasses], HSkip[PNG_Adam7_NumPasses], HOffset[PNG_Adam7_NumPasses];
	uint32_t w, h, p, a;
	byte *OutPtr;
	uint8_t *DecompPtr;
	uint32_t TargetLength;

	/*
	 *  input verification
	 */

	if(!(IHDR && OutBuffer && DecompressedData && DecompressedDataLength && TransparentColour && OutPal))
	{
		return(qfalse);
	}

	/*
	 *  byte swapping
	 */

	IHDR_Width  = BigLong(IHDR->Width);
	IHDR_Height = BigLong(IHDR->Height);

	/*
	 *  Skip and Offset for the passes.
	 */

	WSkip[0]   = 8;
	WOffset[0] = 0;
	HSkip[0]   = 8;
	HOffset[0] = 0;

	WSkip[1]   = 8;
	WOffset[1] = 4;
	HSkip[1]   = 8;
	HOffset[1] = 0;

	WSkip[2]   = 4;
	WOffset[2] = 0;
	HSkip[2]   = 8;
	HOffset[2] = 4;

	WSkip[3]   = 4;
	WOffset[3] = 2;
	HSkip[3]   = 4;
	HOffset[3] = 0;

	WSkip[4]   = 2;
	WOffset[4] = 0;
	HSkip[4]   = 4;
	HOffset[4] = 2;

	WSkip[5]   = 2;
	WOffset[5] = 1;
	HSkip[5]   = 2;
	HOffset[5] = 0;

	WSkip[6]   = 1;
	WOffset[6] = 0;
	HSkip[6]   = 2;
	HOffset[6] = 1;

	/*
	 *  Calculate the sizes of the passes.
	 */

	PassWidth[0]  = (IHDR_Width  + 7) / 8;
	PassHeight[0] = (IHDR_Height + 7) / 8;

	PassWidth[1]  = (IHDR_Width  + 3) / 8;
	PassHeight[1] = (IHDR_Height + 7) / 8;

	PassWidth[2]  = (IHDR_Width  + 3) / 4;
	PassHeight[2] = (IHDR_Height + 3) / 8;

	PassWidth[3]  = (IHDR_Width  + 1) / 4;
	PassHeight[3] = (IHDR_Height + 3) / 4;

	PassWidth[4]  = (IHDR_Width  + 1) / 2;
	PassHeight[4] = (IHDR_Height + 1) / 4;

	PassWidth[5]  = (IHDR_Width  + 0) / 2;
	PassHeight[5] = (IHDR_Height + 1) / 2;

	PassWidth[6]  = (IHDR_Width  + 0) / 1;
	PassHeight[6] = (IHDR_Height + 0) / 2;

	/*
	 *  information for un-filtering
	 */

	switch(IHDR->ColourType)
	{
		case PNG_ColourType_Grey :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_1 :
				case PNG_BitDepth_2 :
				case PNG_BitDepth_4 :
				{
					BytesPerPixel    = 1;
					PixelsPerByte    = 8 / IHDR->BitDepth;

					break;
				}

				case PNG_BitDepth_8  :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_Grey;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_True :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8  :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_True;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_Indexed :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_1 :
				case PNG_BitDepth_2 :
				case PNG_BitDepth_4 :
				{
					BytesPerPixel    = 1;
					PixelsPerByte    = 8 / IHDR->BitDepth;

					break;
				}

				case PNG_BitDepth_8 :
				{
					BytesPerPixel    = PNG_NumColourComponents_Indexed;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_GreyAlpha :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_GreyAlpha;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		case PNG_ColourType_TrueAlpha :
		{
			switch(IHDR->BitDepth)
			{
				case PNG_BitDepth_8 :
				case PNG_BitDepth_16 :
				{
					BytesPerPixel    = (IHDR->BitDepth / 8) * PNG_NumColourComponents_TrueAlpha;
					PixelsPerByte    = 1;

					break;
				}

				default :
				{
					return(qfalse);
				}
			}

			break;
		}

		default :
		{
			return(qfalse);
		}
	}

	/*
	 *  Calculate the size of the scanlines per pass
	 */

	for(a = 0; a < PNG_Adam7_NumPasses; a++)
	{
		BytesPerScanline[a] = (PassWidth[a] * BytesPerPixel + (PixelsPerByte - 1)) / PixelsPerByte;
	}

	/*
	 *  Calculate the size of all passes
	 */

	TargetLength = 0;

	for(a = 0; a < PNG_Adam7_NumPasses; a++)
	{
		TargetLength += ((BytesPerScanline[a] + (BytesPerScanline[a] ? 1 : 0)) * PassHeight[a]);
	}

	/*
	 *  Check if we have enough data for the whole image.
	 */

	if(!(DecompressedDataLength == TargetLength))
	{
		return(qfalse);
	}

	/*
	 *  Unfilter the image.
	 */

	DecompPtr = DecompressedData;

	for(a = 0; a < PNG_Adam7_NumPasses; a++)
	{
		if(!UnfilterImage(DecompPtr, PassHeight[a], BytesPerScanline[a], BytesPerPixel))
		{
			return(qfalse);
		}

		DecompPtr += ((BytesPerScanline[a] + (BytesPerScanline[a] ? 1 : 0)) * PassHeight[a]);
	}

	/*
	 *  Set the working pointers to the beginning of the buffers.
	 */

	DecompPtr = DecompressedData;

	/*
	 *  Create the output image.
	 */

	for(a = 0; a < PNG_Adam7_NumPasses; a++)
	{
		for(h = 0; h < PassHeight[a]; h++)
		{
			/*
			 *  Count the pixels on the scanline for those multipixel bytes
			 */

			uint32_t CurrPixel;

			/*
			 *  skip FilterType
			 *  but only when the pass has a width bigger than zero
			 */

			if(BytesPerScanline[a])
			{
				DecompPtr++;
			}

			/*
			 *  Reset the pixel count.
			 */

			CurrPixel = 0;

			for(w = 0; w < (BytesPerScanline[a] / BytesPerPixel); w++)
			{
				if(PixelsPerByte > 1)
				{
					uint8_t  Mask;
					uint32_t Shift;
					uint8_t  SinglePixel;

					for(p = 0; p < PixelsPerByte; p++)
					{
						if(CurrPixel < PassWidth[a])
						{
							Mask  = (1 << IHDR->BitDepth) - 1;
							Shift = (PixelsPerByte - 1 - p) * IHDR->BitDepth;

							SinglePixel = ((DecompPtr[0] & (Mask << Shift)) >> Shift);

							OutPtr = OutBuffer + (((((h * HSkip[a]) + HOffset[a]) * IHDR_Width) + ((CurrPixel * WSkip[a]) + WOffset[a])) * Q3IMAGE_BYTESPERPIXEL);

							if(!ConvertPixel(IHDR, OutPtr, &SinglePixel, HasTransparentColour, TransparentColour, OutPal))
							{
								return(qfalse);
							}

							CurrPixel++;
						}
					}

				}
				else
				{
					OutPtr = OutBuffer + (((((h * HSkip[a]) + HOffset[a]) * IHDR_Width) + ((w * WSkip[a]) + WOffset[a])) * Q3IMAGE_BYTESPERPIXEL);

					if(!ConvertPixel(IHDR, OutPtr, DecompPtr, HasTransparentColour, TransparentColour, OutPal))
					{
						return(qfalse);
					}
				}

				DecompPtr += BytesPerPixel;
			}
		}
	}

	return(qtrue);
}

/*
 *  The PNG loader
 */

static void *PNG_HeapOutput(int size, void *context) { return malloc(size); }
static void PNG_FreeHeapOutput(void *pixels, void *context) { free(pixels); }

/* Output ownership is supplied by the caller. Temporary decode storage remains
 * private malloc memory; workers never enter renderer allocation callbacks. */
static void PNG_Decode(const byte *bytes, int length, byte **pic, int *width, int *height, size_t maximum,
                       void *(*allocate)(int, void *), void (*release)(void *, void *), void *context)
{
	struct BufferedFile file = { (byte *)bytes, length, (byte *)bytes, length };
	struct BufferedFile *ThePNG = &file;
	byte *OutBuffer;
	uint8_t *Signature;
	struct PNG_ChunkHeader *CH;
	uint32_t ChunkHeaderLength;
	uint32_t ChunkHeaderType;
	struct PNG_Chunk_IHDR *IHDR;
	uint32_t IHDR_Width;
	uint32_t IHDR_Height;
	PNG_ChunkCRC *CRC;
	uint8_t *InPal;
	uint8_t *DecompressedData;
	uint32_t DecompressedDataLength;
	uint32_t i;

	/*
	 *  palette with 256 RGBA entries
	 */

	uint8_t OutPal[1024];

	/*
	 *  transparent colour from the tRNS chunk
	 */

	qboolean HasTransparentColour = qfalse;
	uint8_t TransparentColour[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

	/*
	 *  input verification
	 */

	if(!(bytes && length > 0 && pic))
	{
		return;
	}

	/*
	 *  Zero out return values.
	 */

	*pic = NULL;

	if(width)
	{
		*width = 0;
	}

	if(height)
	{
		*height = 0;
	}

	/*
	 *  Read the siganture of the file.
	 */

	Signature = BufferedFileRead(ThePNG, PNG_Signature_Size);
	if(!Signature)
	{

		return;
	}

	/*
	 *  Is it a PNG?
	 */

	if(memcmp(Signature, PNG_Signature, PNG_Signature_Size))
	{

		return;
	}

	/*
	 *  Read the first chunk-header.
	 */

	CH = BufferedFileRead(ThePNG, PNG_ChunkHeader_Size);
	if(!CH)
	{

		return;
	}

	/*
	 *  PNG multi-byte types are in Big Endian
	 */

	ChunkHeaderLength = BigLong(CH->Length);
	ChunkHeaderType   = BigLong(CH->Type);

	/*
	 *  Check if the first chunk is an IHDR.
	 */

	if(!((ChunkHeaderType == PNG_ChunkType_IHDR) && (ChunkHeaderLength == PNG_Chunk_IHDR_Size)))
	{

		return;
	}

	/*
	 *  Read the IHDR.
	 */

	IHDR = BufferedFileRead(ThePNG, PNG_Chunk_IHDR_Size);
	if(!IHDR)
	{

		return;
	}

	/*
	 *  Read the CRC for IHDR
	 */

	CRC = BufferedFileRead(ThePNG, PNG_ChunkCRC_Size);
	if(!CRC)
	{

		return;
	}

	/*
	 *  Here we could check the CRC if we wanted to.
	 */

	/*
	 *  multi-byte type swapping
	 */

	IHDR_Width  = BigLong(IHDR->Width);
	IHDR_Height = BigLong(IHDR->Height);

	/*
	 *  Check if Width and Height are valid.
	 */

	if(!((IHDR_Width > 0) && (IHDR_Height > 0))
	|| IHDR_Width > INT_MAX / Q3IMAGE_BYTESPERPIXEL / IHDR_Height
	|| (uint64_t)IHDR_Width * IHDR_Height * Q3IMAGE_BYTESPERPIXEL > maximum)
	{

		return;
	}

	/*
	 *  Do we need to check if the dimensions of the image are valid for Quake3?
	 */

	/*
	 *  Check if CompressionMethod and FilterMethod are valid.
	 */

	if(!((IHDR->CompressionMethod == PNG_CompressionMethod_0) && (IHDR->FilterMethod == PNG_FilterMethod_0)))
	{

		return;
	}

	/*
	 *  Check if InterlaceMethod is valid.
	 */

	if(!((IHDR->InterlaceMethod == PNG_InterlaceMethod_NonInterlaced)  || (IHDR->InterlaceMethod == PNG_InterlaceMethod_Interlaced)))
	{

		return;
	}

	/*
	 *  Read palette for an indexed image.
	 */

	if(IHDR->ColourType == PNG_ColourType_Indexed)
	{
		/*
		 *  We need the palette first.
		 */

		if(!FindChunk(ThePNG, PNG_ChunkType_PLTE))
		{

			return;
		}

		/*
		 *  Read the chunk-header.
		 */

		CH = BufferedFileRead(ThePNG, PNG_ChunkHeader_Size);
		if(!CH)
		{

			return;
		}

		/*
		 *  PNG multi-byte types are in Big Endian
		 */

		ChunkHeaderLength = BigLong(CH->Length);
		ChunkHeaderType   = BigLong(CH->Type);

		/*
		 *  Check if the chunk is a PLTE.
		 */

		if(!(ChunkHeaderType == PNG_ChunkType_PLTE))
		{

			return;
		}

		/*
		 *  Check if Length is divisible by 3
		 */

		if(ChunkHeaderLength % 3 || ChunkHeaderLength > 256 * 3)
		{

			return;
		}

		/*
		 *  Read the raw palette data
		 */

		InPal = BufferedFileRead(ThePNG, ChunkHeaderLength);
		if(!InPal)
		{

			return;
		}

		/*
		 *  Read the CRC for the palette
		 */

		CRC = BufferedFileRead(ThePNG, PNG_ChunkCRC_Size);
		if(!CRC)
		{

			return;
		}

		/*
		 *  Set some default values.
		 */

		for(i = 0; i < 256; i++)
		{
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 0] = 0x00;
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 1] = 0x00;
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 2] = 0x00;
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 3] = 0xFF;
		}

		/*
		 *  Convert to the Quake3 RGBA-format.
		 */

		for(i = 0; i < (ChunkHeaderLength / 3); i++)
		{
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 0] = InPal[i*3+0];
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 1] = InPal[i*3+1];
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 2] = InPal[i*3+2];
			OutPal[i * Q3IMAGE_BYTESPERPIXEL + 3] = 0xFF;
		}
	}

	/*
	 *  transparency information is sometimes stored in a tRNS chunk
	 */

	/*
	 *  Let's see if there is a tRNS chunk
	 */

	if(FindChunk(ThePNG, PNG_ChunkType_tRNS))
	{
		uint8_t *Trans;

		/*
		 *  Read the chunk-header.
		 */

		CH = BufferedFileRead(ThePNG, PNG_ChunkHeader_Size);
		if(!CH)
		{

			return;
		}

		/*
		 *  PNG multi-byte types are in Big Endian
		 */

		ChunkHeaderLength = BigLong(CH->Length);
		ChunkHeaderType   = BigLong(CH->Type);

		/*
		 *  Check if the chunk is a tRNS.
		 */

		if(!(ChunkHeaderType == PNG_ChunkType_tRNS))
		{

			return;
		}

		/*
		 *  Read the transparency information.
		 */

		Trans = BufferedFileRead(ThePNG, ChunkHeaderLength);
		if(!Trans)
		{

			return;
		}

		/*
		 *  Read the CRC.
		 */

		CRC = BufferedFileRead(ThePNG, PNG_ChunkCRC_Size);
		if(!CRC)
		{

			return;
		}

		/*
		 *  Only for Grey, True and Indexed ColourType should tRNS exist.
		 */

		switch(IHDR->ColourType)
		{
			case PNG_ColourType_Grey :
			{
				if(ChunkHeaderLength != 2)
				{

					return;
				}

				HasTransparentColour = qtrue;

				/*
				 *  Grey can have one colour which is completely transparent.
				 *  This colour is always stored in 16 bits.
				 */

				TransparentColour[0] = Trans[0];
				TransparentColour[1] = Trans[1];

				break;
			}

			case PNG_ColourType_True :
			{
				if(ChunkHeaderLength != 6)
				{

					return;
				}

				HasTransparentColour = qtrue;

				/*
				 *  True can have one colour which is completely transparent.
				 *  This colour is always stored in 16 bits.
				 */

				TransparentColour[0] = Trans[0];
				TransparentColour[1] = Trans[1];
				TransparentColour[2] = Trans[2];
				TransparentColour[3] = Trans[3];
				TransparentColour[4] = Trans[4];
				TransparentColour[5] = Trans[5];

				break;
			}

			case PNG_ColourType_Indexed :
			{
				/*
				 *  Maximum of 256 one byte transparency entries.
				 */

				if(ChunkHeaderLength > 256)
				{

					return;
				}

				HasTransparentColour = qtrue;

				/*
				 *  alpha values for palette entries
				 */

				for(i = 0; i < ChunkHeaderLength; i++)
				{
					OutPal[i * Q3IMAGE_BYTESPERPIXEL + 3] = Trans[i];
				}

				break;
			}

			/*
			 *  All other ColourTypes should not have tRNS chunks
			 */

			default :
			{

				return;
			}
		}
	}

	/*
	 *  Rewind to the start of the file.
	 */

	if(!BufferedFileRewind(ThePNG, (unsigned)-1))
	{

		return;
	}

	/*
	 *  Skip the signature
	 */

	if(!BufferedFileSkip(ThePNG, PNG_Signature_Size))
	{

		return;
	}

	/*
	 *  Decompress all IDAT chunks
	 */

	DecompressedDataLength = DecompressIDATs(ThePNG, &DecompressedData, PNG_FilteredSize(IHDR));
	if(!(DecompressedDataLength && DecompressedData))
	{

		return;
	}

	/*
	 *  Allocate output buffer.
	 */

	OutBuffer = allocate(IHDR_Width * IHDR_Height * Q3IMAGE_BYTESPERPIXEL, context);
	if(!OutBuffer)
	{
		free(DecompressedData);

		return;
	}

	/*
	 *  Interlaced and Non-interlaced images need to be handled differently.
	 */

	switch(IHDR->InterlaceMethod)
	{
		case PNG_InterlaceMethod_NonInterlaced :
		{
			if(!DecodeImageNonInterlaced(IHDR, OutBuffer, DecompressedData, DecompressedDataLength, HasTransparentColour, TransparentColour, OutPal))
			{
				release(OutBuffer, context);
				free(DecompressedData);

				return;
			}

			break;
		}

		case PNG_InterlaceMethod_Interlaced :
		{
			if(!DecodeImageInterlaced(IHDR, OutBuffer, DecompressedData, DecompressedDataLength, HasTransparentColour, TransparentColour, OutPal))
			{
				release(OutBuffer, context);
				free(DecompressedData);

				return;
			}

			break;
		}

		default :
		{
			release(OutBuffer, context);
			free(DecompressedData);

			return;
		}
	}

	/*
	 *  update the pointer to the image data
	 */

	*pic = OutBuffer;

	/*
	 *  Fill width and height.
	 */

	if(width)
	{
		*width = IHDR_Width;
	}

	if(height)
	{
		*height = IHDR_Height;
	}

	/*
	 *  DecompressedData is not needed anymore.
	 */

	free(DecompressedData);

	/*
	 *  We have all data, so close the file.
	 */

}

void R_DecodePNG(const byte *bytes, int length, byte **pic, int *width, int *height, size_t maximum) {
    PNG_Decode(bytes, length, pic, width, height, maximum, PNG_HeapOutput, PNG_FreeHeapOutput, NULL);
}

/* Owner-thread cache of expensive canonical pixels. Renderer restarts release
 * GPU/media allocations but can retain these immutable inputs/results. Compare
 * every input byte (not a path, timestamp or short hash), so changed/corrupt
 * assets cannot reuse a stale decoded image. A full cache retains its initial
 * working set instead of thrashing on a one-pass stream of large new images. */
#ifndef DK3_PNG_CACHE_MIN_BYTES
#define DK3_PNG_CACHE_MIN_BYTES (32u << 20)
#endif
typedef struct {
    byte *input, *pixels;
    int length, width, height;
} pngDecodeCache_t;
static pngDecodeCache_t pngDecodeCache[16];
static unsigned pngDecodeCacheCount;
static size_t pngDecodeCacheBytes;
static cvar_t *pngDecodeCacheSetting;

void R_ClearPNGCache(void) {
    unsigned i;
    for (i = 0; i < pngDecodeCacheCount; ++i) {
        free(pngDecodeCache[i].input);
        free(pngDecodeCache[i].pixels);
    }
    memset(pngDecodeCache, 0, sizeof(pngDecodeCache));
    pngDecodeCacheCount = 0;
    pngDecodeCacheBytes = 0;
    pngDecodeCacheSetting = NULL;
}
static size_t PNG_CacheBudget(void) {
    int megs;
    if (!pngDecodeCacheSetting && ri.Cvar_Get)
        pngDecodeCacheSetting = ri.Cvar_Get("r_imageDecodeCacheMegs", "256", CVAR_ARCHIVE);
    megs = pngDecodeCacheSetting ? pngDecodeCacheSetting->integer : 0;
    size_t budget = (size_t)(megs < 0 ? 0 : megs > 1024 ? 1024 : megs) << 20;
    if (pngDecodeCacheBytes > budget) R_ClearPNGCache();
    return budget;
}
static pngDecodeCache_t *PNG_Cached(const byte *bytes, int length) {
    unsigned i;
    for (i = 0; i < pngDecodeCacheCount; ++i) {
        pngDecodeCache_t *entry = &pngDecodeCache[i];
        if (entry->length == length && !memcmp(entry->input, bytes, length)) return entry;
    }
    return NULL;
}
static qboolean PNG_CanRetain(size_t size, int length, size_t budget) {
    size_t required = size + length;
    return size >= DK3_PNG_CACHE_MIN_BYTES && pngDecodeCacheCount < ARRAY_LEN(pngDecodeCache) &&
           required <= budget && pngDecodeCacheBytes <= budget - required;
}
static qboolean PNG_Retain(const byte *bytes, int length, byte *pixels, int width, int height, size_t budget) {
    size_t size = (size_t)width * height * 4, required = size + length;
    byte *input;
    pngDecodeCache_t *entry;
    if (!PNG_CanRetain(size, length, budget)) return qfalse;
    input = malloc(length);
    if (!input) return qfalse;
    memcpy(input, bytes, length);
    entry = &pngDecodeCache[pngDecodeCacheCount++];
    entry->input = input; entry->length = length; entry->pixels = pixels;
    entry->width = width; entry->height = height;
    pngDecodeCacheBytes += required;
    return qtrue;
}

qboolean R_CopyCachedPNG(const byte *bytes, int length, byte **pic, int *width, int *height, size_t maximum) {
    pngDecodeCache_t *entry;
    size_t size;
    byte *copy;
    if (!bytes || length <= 0 || !pic || !width || !height || !PNG_CacheBudget()) return qfalse;
    entry = PNG_Cached(bytes, length);
    if (!entry) return qfalse;
    size = (size_t)entry->width * entry->height * 4;
    if (size > maximum || !(copy = malloc(size))) return qfalse;
    memcpy(copy, entry->pixels, size);
    *pic = copy; *width = entry->width; *height = entry->height;
    return qtrue;
}
void R_RetainPreparedPNG(const byte *bytes, int length, const byte *pixels, int width, int height) {
    size_t size, budget;
    byte *copy;
    if (!bytes || length <= 0 || !pixels || width <= 0 || height <= 0 || width > INT_MAX / 4 / height) return;
    size = (size_t)width * height * 4;
    budget = PNG_CacheBudget();
    if (!PNG_CanRetain(size, length, budget) || PNG_Cached(bytes, length)) return;
    copy = malloc(size);
    if (!copy) return;
    memcpy(copy, pixels, size);
    if (!PNG_Retain(bytes, length, copy, width, height, budget)) free(copy);
}

typedef struct {
    size_t budget;
    int length;
    qboolean rendererOwned;
} pngOwnerOutput_t;
static void *PNG_OwnerOutput(int size, void *context) {
    pngOwnerOutput_t *output = context;
    if (PNG_CanRetain(size, output->length, output->budget)) return malloc(size);
    output->rendererOwned = qtrue;
    return ri.Malloc(size);
}
static void PNG_FreeOwnerOutput(void *pixels, void *context) {
    if (((pngOwnerOutput_t *)context)->rendererOwned) ri.Free(pixels);
    else free(pixels);
}

/* Synchronous callers and background admission share precisely one decoder.
 * Worker output is malloc-owned; only the owner thread touches renderer/FS
 * allocators. Returning pixels preserves the existing ri.Free contract. */
void R_LoadPNG(const char *name, byte **pic, int *width, int *height) {
    void *bytes = NULL;
    byte *decoded = NULL;
    int length, decodedWidth = 0, decodedHeight = 0;
    size_t budget = PNG_CacheBudget();
    qboolean retained = qfalse;
    pngDecodeCache_t *cached;
    pngOwnerOutput_t output = {0};
    *pic = NULL;
    if (width) *width = 0;
    if (height) *height = 0;
    if (R_TakePreparedPNG(name, pic, width, height)) return;
    length = ri.FS_ReadFile(name, &bytes);
    if (!bytes || length <= 0) { if (bytes) ri.FS_FreeFile(bytes); return; }
    cached = PNG_Cached(bytes, length);
    if (cached) {
        decoded = cached->pixels; decodedWidth = cached->width; decodedHeight = cached->height;
        retained = qtrue;
        ri.Printf(PRINT_DEVELOPER, "dk3 PNG cache: hit=%s retained_bytes=%lu\n", name, (unsigned long)pngDecodeCacheBytes);
    } else {
        output.budget = budget;
        output.length = length;
        PNG_Decode(bytes, length, &decoded, &decodedWidth, &decodedHeight, INT_MAX,
                   PNG_OwnerOutput, PNG_FreeOwnerOutput, &output);
        if (decoded && !output.rendererOwned) retained = PNG_Retain(bytes, length, decoded, decodedWidth, decodedHeight, budget);
    }
    ri.FS_FreeFile(bytes);
    if (decoded) {
        size_t size = (size_t)decodedWidth * decodedHeight * 4;
        if (width) *width = decodedWidth;
        if (height) *height = decodedHeight;
        if (output.rendererOwned) *pic = decoded;
        else {
            *pic = ri.Malloc(size);
            memcpy(*pic, decoded, size);
            if (!retained) free(decoded);
        }
    }
}
