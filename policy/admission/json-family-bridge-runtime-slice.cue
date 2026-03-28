package admission

#EntryClass:       "authoring_surface" | "bridge_class" | "runtime_actor_class" | "guardrail"
#AuthorityStatus:  "authoritative" | "derived"
#PromotionDefault: "blocked" | "not_applicable"

#Entry: {
	entry_id:         string
	entry_class:      #EntryClass
	summary:          string
	authority_status: #AuthorityStatus
	source_refs: [...string] & [string, ...string]
	consumes?: [...string]
	produces?: [...string]
	promotion_default:          #PromotionDefault
	lineage_sink_required:      bool
	emitter_side_effect_class?: string
}

#Normalized: {
	kind:              "kernel.bridge_runtime_registry.slice_input"
	control_object_id: "json-family-bridge-runtime-slice"
	source_module_id:  "json-family-bridge-runtime-slice"
	source_module_ref: "structures/extensions/json-family-bridge-runtime-slice.module.json"
	kernel_policy_ref: "policy/kernel/json-family-bridge-runtime.index.json"
	export_schema_ref: "schemas/exported/json-family-bridge-runtime-slice-input.schema.json"
	generator_ref:     "manifests/generators/json-family-bridge-runtime-slice.generator.json"
	projection_ref:    "manifests/projections/json-family-bridge-runtime-slice.projection.json"
	output_path:       "generated/registries/json-family-bridge-runtime.index.json"
	entries: [...#Entry] & [#Entry, ...#Entry]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
