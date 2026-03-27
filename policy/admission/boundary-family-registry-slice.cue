package admission

#EntryStatus: "materialized" | "partial"
#Plane: "structure" | "control" | "policy"
#PolicyScopeStatus: "placeholder_only" | "structural_only"

#Entry: {
	family:               string
	plane:                #Plane
	summary:              string
	source_refs:          [...string] & [string, ...string]
	derived_contract_ref: string
	evidence_refs:        [...string] & [string, ...string]
	status:               #EntryStatus
}

#Normalized: {
	kind:                "kernel.boundary_family_registry.slice_input"
	control_object_id:   "boundary-family-registry-slice"
	registry_id:         "kernel-boundary-families"
	source_module_id:    "boundary-family-registry-slice"
	source_module_ref:   "structures/core/boundary-family-registry-slice.module.json"
	policy_scope_ref:    "policy/admission/scope.index.json"
	policy_scope_status: #PolicyScopeStatus
	export_schema_ref:   "schemas/exported/boundary-family-registry-slice-input.schema.json"
	generator_ref:       "manifests/generators/boundary-family-registry-slice.generator.json"
	projection_ref:      "manifests/projections/boundary-family-registry-slice.projection.json"
	output_path:         "generated/registries/boundary-families.index.json"
	entries:             [...#Entry] & [#Entry, ...#Entry]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
