package admission

#Status: "BLOCKED" | "OPEN" | "DONE" | "INVALID"

#Normalized: {
	kind:                "kernel.core_closeout_status.slice_input"
	control_object_id:   "core-closeout-status-slice"
	source_module_id:    "core-closeout-status-slice"
	source_module_ref:   "structures/core/core-closeout-status-slice.module.json"
	closeout_manifest_ref: "manifests/bundles/kernel-core-json-structure-closeout.manifest.json"
	export_schema_ref:   "schemas/exported/core-closeout-status-slice-input.schema.json"
	generator_ref:       "manifests/generators/core-closeout-status-slice.generator.json"
	projection_ref:      "manifests/projections/core-closeout-status-slice.projection.json"
	output_path:         "generated/docs/reference/operational-status.md"
	current_status:      #Status
	decision_basis:      [...string]
	blockers:            [...string]
	implemented_slices:  [...string]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "documentation"
		runtime:      string
		runtime_path: string
	}
	if current_status == "BLOCKED" {
		blockers: [...string] & [string, ...string]
	}
}
