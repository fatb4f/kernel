local admitted = std.parseJson(std.extVar('admitted_state'));
{
  artifact_type: 'kernel.metadata_metaschema_lane_registry',
  artifact_version: '0.1.0',
  source_module_ref: admitted.source_module_ref,
  kernel_policy_ref: admitted.kernel_policy_ref,
  contract_note_ref: admitted.contract_note_ref,
  lane_dependency_ref: admitted.lane_dependency_ref,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
  authoritative_middle: admitted.authoritative_middle,
  entries: admitted.entries,
  lane_order: admitted.lane_order,
}
