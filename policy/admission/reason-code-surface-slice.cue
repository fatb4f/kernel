package admission

#FamilyId: "SRC" | "EXPORT" | "NORM" | "ADMIT" | "RENDER" | "DRIFT"

#FamilyEntry: {
	family_id:      #FamilyId
	prefix:         string
	gate:           "G1" | "G2" | "G3" | "G4" | "G5" | "G6"
	description:    string
	declared_refs:  [...string] & [string, ...string]
	observed_codes: [...string]
	status:         "declared_only" | "observed"
}

#Normalized: {
	kind:                "kernel.reason_code_surface.slice_input"
	control_object_id:   "reason-code-surface-slice"
	source_module_id:    "reason-code-surface-slice"
	source_module_ref:   "structures/core/reason-code-surface-slice.module.json"
	export_schema_ref:   "schemas/exported/reason-code-surface-slice-input.schema.json"
	generator_ref:       "manifests/generators/reason-code-surface-slice.generator.json"
	projection_ref:      "manifests/projections/reason-code-surface-slice.projection.json"
	output_path:         "generated/registries/reason-code-surfaces.index.json"
	families:            [...#FamilyEntry] & [#FamilyEntry, ...#FamilyEntry]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
