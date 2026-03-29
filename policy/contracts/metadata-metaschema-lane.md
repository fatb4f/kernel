# Metadata Metaschema Lane

## rooted-source-registry

The rooted source registry is the ingress identity surface for the metadata-first prose-to-structure lane.

It records repo-rooted identity, current location, source class, authority role, and provenance without introducing a second metadata lane for projections.

## structural-units

Structural units are the first-class intermediate extraction layer between rooted sources and the canonical semantic model.

They preserve source provenance, unit identity, candidate section mapping, and term candidates before normalization.

## canonical-semantic-model

The canonical semantic model is the authoritative middle of the metadata-first transform chain.

It is projection-neutral and carries normalized objects, relations, open questions, and projection targets.

Document-shaped outputs, summaries, inventories, manifests, and other projections are derived downstream from this surface.

## projection-binding

Projection bindings are downstream contracts from semantic targets to emitted artifacts.

They describe what is projected, not what is authoritative.

## lane-order

The metaschema model is upstream semantic authority.

Workflow docs are explanatory projections of that model and must not back-author its semantics.

The scm.pattern workflow is a downstream operational carrier and must not define semantic authority.
