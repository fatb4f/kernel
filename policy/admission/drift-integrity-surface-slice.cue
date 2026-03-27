package admission

#DriftStatus: "PASS" | "FAIL"

#GeneratedClass: {
	class_id:      string
	root:          string
	commit_policy: string
	authority:     string
}

#BuildClass: {
	class_id:      string
	root:          string
	commit_policy: string
	authority:     string
}

#DriftRun: {
	control_object_id: string
	run_id:            string
	status:            #DriftStatus
	checks:            [...string] & [string, ...string]
}

#Normalized: {
	kind:                "kernel.drift_integrity_surface.slice_input"
	control_object_id:   "drift-integrity-surface-slice"
	source_module_id:    "drift-integrity-surface-slice"
	source_module_ref:   "structures/core/drift-integrity-surface-slice.module.json"
	boundary_ref:        "policy/data/generated-build-boundary.json"
	export_schema_ref:   "schemas/exported/drift-integrity-surface-slice-input.schema.json"
	generator_ref:       "manifests/generators/drift-integrity-surface-slice.generator.json"
	projection_ref:      "manifests/projections/drift-integrity-surface-slice.projection.json"
	output_path:         "generated/registries/drift-integrity-surfaces.index.json"
	generated_classes:   [...#GeneratedClass] & [#GeneratedClass, ...#GeneratedClass]
	build_classes:       [...#BuildClass] & [#BuildClass, ...#BuildClass]
	invariants:          [...string] & [string, ...string]
	drift_runs:          [...#DriftRun] & [#DriftRun, ...#DriftRun]
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
