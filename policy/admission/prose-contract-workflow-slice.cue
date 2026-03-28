package admission

#EntryClass: "term_binding" | "workflow_rule" | "export_family" | "lineage_expectation"

#Entry: {
	entry_id:    string
	entry_class: #EntryClass
	summary:     string
	source_refs: [...string] & [string, ...string]
	authority_role: "pre_contract" | "contract_surface" | "derived" | "non_authoritative"
}

#Normalized: {
	kind:              "kernel.prose_contract_workflow.slice_input"
	control_object_id: "prose-contract-workflow-slice"
	source_module_id:  "prose-contract-workflow-slice"
	source_module_ref: "structures/extensions/prose-contract-workflow-slice.module.json"
	kernel_policy_ref: "policy/kernel/prose-contract-workflow.index.json"
	contract_note_ref: "policy/contracts/prose-contract-workflow.md"
	lineage_ref:       "policy/data/prose-contract-lineage.index.json"
	export_schema_ref: "schemas/exported/prose-contract-workflow-slice-input.schema.json"
	generator_ref:     "manifests/generators/prose-contract-workflow-slice.generator.json"
	projection_ref:    "manifests/projections/prose-contract-workflow-slice.projection.json"
	output_path:       "generated/registries/prose-contract-workflow.index.json"
	entries: [...#Entry] & [#Entry, ...#Entry]
	preferred_export_bundle: {
		members: [...string] & [string, ...string]
		merged_convenience_export: "optional_derived_only"
	}
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
