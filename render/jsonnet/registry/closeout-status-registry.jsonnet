local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.closeout_status_registry',
  artifact_version: '0.1.0',
  registry_id: admitted.registry_id,
  current_gate_status: admitted.current_gate_status,
  blockers: admitted.blockers,
  refs: {
    source_module_ref: admitted.source_module_ref,
    closeout_manifest_ref: admitted.closeout_manifest_ref,
    boundary_registry_ref: admitted.boundary_registry_ref,
    operational_status_ref: admitted.operational_status_ref,
  },
  checklist_statuses: admitted.checklist_statuses,
  component_statuses: admitted.component_statuses,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
}
