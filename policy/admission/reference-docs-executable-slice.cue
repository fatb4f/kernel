package admission

#SectionID: "overview" | "pipeline" | "gates" | "admission"

#Normalized: {
	kind:              "kernel.reference_docs.slice_input"
	control_object_id: "reference-docs-executable-slice"
	source_module_id:  "reference-docs-executable-slice"
	source_module_ref: "structures/core/reference-docs-executable-slice.module.json"
	export_schema_ref: "schemas/exported/reference-docs-executable-slice-input.schema.json"
	generator_ref:     "manifests/generators/reference-docs-executable-slice.generator.json"
	projection_ref:    "manifests/projections/reference-docs-executable-slice.projection.json"
	output_path:       "generated/docs/reference/executable-slice.md"
	gate_model: ["G1", "G2", "G3", "G4", "G5", "G6"]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "documentation"
		runtime:      string
		runtime_path: string
	}
	sections: [...{
		id:         #SectionID
		title:      string
		summary:    string
		source_refs: [...string]
	}]
}
