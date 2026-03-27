package admission

#GroupStatus: "materialized" | "partial"

#EvidenceEntry: {
	id:            string
	label:         string
	status:        #GroupStatus
	evidence_refs: [...string] & [string, ...string]
}

#ObligationGroup: {
	status:        #GroupStatus
	evidence_refs: [...string] & [string, ...string]
	items:         [...#EvidenceEntry] & [#EvidenceEntry, ...#EvidenceEntry]
}

#Normalized: {
	kind:              "kernel.completion_obligations_surface.slice_input"
	control_object_id: "completion-obligations-surface-slice"
	source_module_id:  "completion-obligations-surface-slice"
	source_module_ref: "structures/core/completion-obligations-surface-slice.module.json"
	export_schema_ref: "schemas/exported/completion-obligations-surface-slice-input.schema.json"
	generator_ref:     "manifests/generators/completion-obligations-surface-slice.generator.json"
	projection_ref:    "manifests/projections/completion-obligations-surface-slice.projection.json"
	output_path:       "generated/registries/completion-obligations.index.json"
	overall_status:    #GroupStatus
	obligation_groups: {
		invariants:            #ObligationGroup
		artifact_classes:      #ObligationGroup
		implementation_order:  #ObligationGroup
		completion_conditions: #ObligationGroup
		toolchain_control:     #ObligationGroup
	}
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
