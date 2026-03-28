local admitted = std.extVar('admitted_state');
{
  artifact_type: 'kernel.problem_set.summary',
  artifact_version: '0.1.0',
  problem_set_id: admitted.problem_set_id,
  title: admitted.identity.title,
  status: admitted.status,
  objective: admitted.objective,
  scope: admitted.scope,
  requested_outputs: admitted.requested_outputs,
  authority_refs: admitted.authority_refs,
  acceptance_criteria: admitted.acceptance_criteria,
  admission: admitted.admission,
  fingerprint: admitted.fingerprint,
}
