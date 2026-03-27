local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.chatgpt_packet_family_registry',
  artifact_version: '0.1.0',
  registry_id: admitted.registry_id,
  family_root: admitted.family_root,
  source_module_ref: admitted.source_module_ref,
  approval_state: admitted.approval_state,
  generated_from: {
    control_object_id: admitted.control_object_id,
    output_path: admitted.output_path,
  },
  entries: [
    {
      schema_id: entry.schema_id,
      schema_role: entry.schema_role,
      schema_ref: entry.schema_ref,
      workflow_binding_refs: entry.workflow_binding_refs,
      source_refs: entry.source_refs,
      summary: entry.summary,
      status: entry.status,
    }
    for entry in admitted.entries
  ],
}
