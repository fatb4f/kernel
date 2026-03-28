local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.prose_contract_workflow_registry',
  artifact_version: '0.1.0',
  source_module_ref: admitted.source_module_ref,
  kernel_policy_ref: admitted.kernel_policy_ref,
  contract_note_ref: admitted.contract_note_ref,
  lineage_ref: admitted.lineage_ref,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
  entries: admitted.entries,
  preferred_export_bundle: admitted.preferred_export_bundle,
}
