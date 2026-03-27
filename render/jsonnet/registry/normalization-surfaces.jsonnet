local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.normalization_surface_registry',
  artifact_version: '0.1.0',
  source_module_ref: admitted.source_module_ref,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
  slices: admitted.slices,
}
