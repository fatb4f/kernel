local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.boundary_family_registry',
  artifact_version: '0.1.0',
  registry_id: admitted.registry_id,
  source_module_ref: admitted.source_module_ref,
  policy_scope_ref: admitted.policy_scope_ref,
  policy_scope_status: admitted.policy_scope_status,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
  entries: [
    {
      family: entry.family,
      plane: entry.plane,
      summary: entry.summary,
      derived_contract_ref: entry.derived_contract_ref,
      source_refs: entry.source_refs,
      evidence_refs: entry.evidence_refs,
      status: entry.status,
    }
    for entry in admitted.entries
  ],
}
