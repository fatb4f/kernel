package admission

#SliceEntry: {
	control_object_id:     string
	run_id:                string
	normalized_state_ref:  string
	source_map_ref:        string
	report_ref:            string
	report_status:         "PASS" | "FAIL"
	operations:            [...string] & [string, ...string]
}

#Normalized: {
	kind:                "kernel.normalization_surface.slice_input"
	control_object_id:   "normalization-surface-slice"
	source_module_id:    "normalization-surface-slice"
	source_module_ref:   "structures/core/normalization-surface-slice.module.json"
	export_schema_ref:   "schemas/exported/normalization-surface-slice-input.schema.json"
	generator_ref:       "manifests/generators/normalization-surface-slice.generator.json"
	projection_ref:      "manifests/projections/normalization-surface-slice.projection.json"
	output_path:         "generated/registries/normalization-surfaces.index.json"
	slices:              [...#SliceEntry] & [#SliceEntry, ...#SliceEntry]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
