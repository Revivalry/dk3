# SPDX-License-Identifier: GPL-2.0-or-later
"""Local admission manifest; geometry reviews are pinned to both exact BSPs.

Unreviewed corridors retain authored landing travel. They are prefetched but never
silently promoted to continuous seams. This file contains no reference runtime.
"""
import campaign_connections
import hashlib
import json
from pathlib import Path
import sys

from portable_lock import locked

# Sequences 298/581: shared corridor geometry and authored reciprocal brushes.
# The 581 comparison preserves every entity, plane, model and render-geometry
# lump. Only distant water-current contents changed; side surface semantics are
# identical. Renew the exact BSP pins without weakening admission to new assets.
# Evidence: gameplay-stability-581/transition-inputs/seam-bsp-comparison.json.
# Identity is a measured transform, not a spawn-name fallback.
REVIEWED = {
    'e1m1a': '6c0b7f17620ad8614649b1cb70c258c68edf40b150a88c0e68462ed66759e9e4',
    'e1m1b': '049d13238b73a0a85cd7116ffc98e6887b6f4fec054ac91818e90e3f183c51b4',
    'e1m1c': '799a65e78e26774d391f70991ed7bcd162efedf81c34014bd5e6c8e33a4b34e9',
}
SEAMS = {('e1m1a', 25): ('e1m1b', 449),
         ('e1m1b', 449): ('e1m1a', 25),
         ('e1m1b', 97): ('e1m1c', 410),
         ('e1m1c', 410): ('e1m1b', 97),
         ('e1m1b', 105): ('e1m1c', 411),
         ('e1m1c', 411): ('e1m1b', 105)}
# Outward normals of the reviewed corridor brushes. These select the outgoing
# face, not a translation derived from the deliberately separated return trigger.
NORMALS = {('e1m1a', 25): (0, 1), ('e1m1b', 449): (0, -1),
           ('e1m1b', 97): (1, 1), ('e1m1c', 410): (1, -1),
           ('e1m1b', 105): (0, 1), ('e1m1c', 411): (0, -1)}


def encode(document):
    rows = ['dk3_table 1']
    for name, entry in sorted(document['maps'].items()):
        rows.append(f'{{ map "{name}" sha256 "{entry["sha256"]}" }}')
    for edge in document['connections']:
        if edge['status'] == 'invalid':
            raise ValueError(f"invalid campaign exit: {edge['source']}:{edge['entity']}")
        source, destination = edge['source'], edge['destination']
        kind = 'cut' if edge['status'] == 'authored_cut' else 'landing'
        reviewed = SEAMS.get((source, edge['entity']))
        reciprocal = 0
        if reviewed and reviewed[0] == destination and all(
                document['maps'][name]['sha256'] == REVIEWED.get(name)
                for name in (source, destination)):
            reciprocal = reviewed[1]
            if reciprocal not in edge['return_exit_candidates']:
                raise ValueError('reviewed seam lost its reciprocal exit')
            kind = 'identity'
        normal = ''
        if kind == 'identity':
            axis, sign = NORMALS[(source, edge['entity'])]
            normal = f' axis "{axis}" direction "{sign}"'
        rows.append(f'{{ source "{source}" destination "{destination}" exit "{edge["entity"]}" '
                    f'kind "{kind}" reciprocal "{reciprocal}"{normal} }}')
    return '\n'.join(rows) + '\n'


def build(package):
    return encode(campaign_connections.build(package))


def _derivation_identity():
    digest = hashlib.sha256()
    for filename in (__file__, campaign_connections.__file__, campaign_connections.entities.__file__,
                     campaign_connections.entities.dkbsp.__file__):
        path = Path(filename)
        digest.update(path.name.encode() + b'\0' + path.read_bytes() + b'\0')
    return digest.hexdigest()


def cached_build(package, output, *, verified_package_sha256=None):
    """Reuse derived authoring only after package identity has been verified.

    play.install supplies the SHA-256 it already checked; standalone callers
    hash their input here. Both tooling changes and damaged cached output cause
    regeneration, without weakening the caller's asset/package validation.
    """
    package, output = Path(package), Path(output)
    if verified_package_sha256 is None:
        with package.open('rb') as stream:
            verified_package_sha256 = hashlib.file_digest(stream, 'sha256').hexdigest()
    identity = dict(maps_sha256=verified_package_sha256, tools_sha256=_derivation_identity(),
                    python=list(sys.version_info[:2]))
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt = output.with_suffix(output.suffix + '.inputs.json')
    with locked(output.with_suffix(output.suffix + '.lock')):
        try:
            metadata = json.loads(receipt.read_text())
            data = output.read_bytes()
            if (isinstance(metadata, dict) and metadata.get('inputs') == identity and
                    metadata.get('output_sha256') == hashlib.sha256(data).hexdigest()):
                return data.decode('utf-8')
        except (OSError, ValueError):
            pass
        result = build(package)
        data = result.encode('utf-8')
        temporary = output.with_suffix(output.suffix + '.partial')
        temporary.write_bytes(data)
        temporary.replace(output)
        temporary = receipt.with_suffix(receipt.suffix + '.partial')
        temporary.write_text(json.dumps(dict(inputs=identity, output_sha256=hashlib.sha256(data).hexdigest()),
                                        sort_keys=True) + '\n')
        temporary.replace(receipt)
        return result
