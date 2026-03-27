package admission

#ScopeName: "kernel" | "admission" | "data"
#ScopeStatus: "placeholder_only" | "structural_only"

#ScopeEntry: {
	scope:               #ScopeName
	status:              #ScopeStatus
	summary:             string
	allowed_content:     [...string] & [string, ...string]
	excluded_content:    [...string] & [string, ...string]
	derived_from:        [...string]
	supporting_refs:     [...string] & [string, ...string]
}

#Normalized: {
	kind:                "kernel.policy_scope_surface.slice_input"
	control_object_id:   "policy-scope-surface-slice"
	source_module_id:    "policy-scope-surface-slice"
	source_module_ref:   "structures/core/policy-scope-surface-slice.module.json"
	export_schema_ref:   "schemas/exported/policy-scope-surface-slice-input.schema.json"
	generator_ref:       "manifests/generators/policy-scope-surface-slice.generator.json"
	projection_ref:      "manifests/projections/policy-scope-surface-slice.projection.json"
	output_path:         "generated/registries/policy-scope-surfaces.index.json"
	scopes:              [...#ScopeEntry] & [#ScopeEntry, ...#ScopeEntry]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
