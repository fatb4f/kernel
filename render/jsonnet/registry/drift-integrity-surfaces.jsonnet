local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.drift_integrity_surface_registry',
  artifact_version: '0.1.0',
  source_module_ref: admitted.source_module_ref,
  boundary_ref: admitted.boundary_ref,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
  generated_classes: admitted.generated_classes,
  build_classes: admitted.build_classes,
  invariants: admitted.invariants,
  drift_runs: admitted.drift_runs,
}
