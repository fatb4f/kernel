package admission

#ObservedStatus: "open" | "partial" | "materialized"
#GateStatus: "BLOCKED" | "OPEN" | "DONE" | "INVALID"

#ChecklistStatus: {
	id:             string
	label:          string
	manifest_status: "open" | "done"
	observed_status: #ObservedStatus
	evidence_refs:  [...string] & [string, ...string]
}

#ComponentStatus: {
	id:             string
	name:           string
	plane:          string
	manifest_status: "open" | "done"
	observed_status: #ObservedStatus
	evidence_refs:  [...string] & [string, ...string]
}

#Normalized: {
	kind:                "kernel.closeout_status_registry.slice_input"
	control_object_id:   "closeout-status-registry-slice"
	registry_id:         "kernel-core-closeout-status"
	source_module_id:    "closeout-status-registry-slice"
	source_module_ref:   "structures/core/closeout-status-registry-slice.module.json"
	closeout_manifest_ref: "manifests/bundles/kernel-core-json-structure-closeout.manifest.json"
	boundary_registry_ref: "generated/registries/boundary-families.index.json"
	operational_status_ref: "generated/docs/reference/operational-status.md"
	export_schema_ref:   "schemas/exported/closeout-status-registry-slice-input.schema.json"
	generator_ref:       "manifests/generators/closeout-status-registry-slice.generator.json"
	projection_ref:      "manifests/projections/closeout-status-registry-slice.projection.json"
	output_path:         "generated/registries/kernel-core-closeout-status.index.json"
	current_gate_status: #GateStatus
	blockers:            [...string]
	checklist_statuses:  [...#ChecklistStatus] & [#ChecklistStatus, ...#ChecklistStatus]
	component_statuses:  [...#ComponentStatus] & [#ComponentStatus, ...#ComponentStatus]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
