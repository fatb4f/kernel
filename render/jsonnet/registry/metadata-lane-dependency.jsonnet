local admitted = std.parseJson(std.extVar('admitted_state'));
{
  artifact_type: 'kernel.metadata_lane_dependency_registry',
  artifact_version: '0.1.0',
  source_module_ref: admitted.source_module_ref,
  kernel_policy_ref: admitted.kernel_policy_ref,
  lane_dependency_ref: admitted.lane_dependency_ref,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: 'generated/registries/metadata-lane-dependency.index.json',
  },
  semantic_authority_lane: admitted.lane_order.semantic_authority_lane,
  allowed_edges: admitted.lane_order.allowed_edges,
  forbidden_edges: admitted.lane_order.forbidden_edges,
}
