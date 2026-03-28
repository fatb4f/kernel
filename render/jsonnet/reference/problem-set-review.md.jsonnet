local admitted = std.extVar('admitted_state');
local scope_controls = if std.objectHas(admitted, 'scope_controls') then admitted.scope_controls else {};
local handoff = if std.objectHas(admitted, 'handoff') then admitted.handoff else {};

local bulletList(items) =
  if std.length(items) == 0 then ['- none'] else ['- ' + item for item in items];

local section(title, items) =
  ['## ' + title] + bulletList(items) + [''];

local scopeControlLines =
  std.flattenArrays([
    ['- `' + key + '`: ' + std.join(', ', scope_controls[key])]
    for key in std.objectFields(scope_controls)
  ]);

std.join('\n',
  [
    '# ' + admitted.identity.title,
    '',
    '## Contract',
    '- `problem_set_id`: `' + admitted.problem_set_id + '`',
    '- `status`: `' + admitted.status + '`',
    '- `version`: `' + admitted.version + '`',
    '- `fingerprint`: `' + admitted.fingerprint.value + '`',
    '',
    '## Objective',
    admitted.objective,
    '',
  ] +
  section('In Scope', admitted.scope.in_scope) +
  section('Out Of Scope', admitted.scope.out_of_scope) +
  (if std.length(admitted.constraints) == 0 then [] else section('Constraints', admitted.constraints)) +
  (if std.length(admitted.requested_outputs) == 0 then [] else section('Requested Outputs', admitted.requested_outputs)) +
  (if std.length(admitted.authority_refs) == 0 then [] else section('Authority Refs', ['`' + item + '`' for item in admitted.authority_refs])) +
  (if std.length(admitted.acceptance_criteria) == 0 then [] else section('Acceptance Criteria', admitted.acceptance_criteria)) +
  (if !std.objectHas(admitted, 'review_criteria') || std.length(admitted.review_criteria) == 0 then [] else section('Review Criteria', admitted.review_criteria)) +
  (
    if std.length(std.objectFields(scope_controls)) == 0 then [] else
    ['## Scope Controls'] + scopeControlLines + ['']
  ) +
  (
    if std.length(std.objectFields(handoff)) == 0 then [] else
    ['## Handoff'] +
    (if std.objectHas(handoff, 'issue_title_prefix') then ['- `issue_title_prefix`: `' + handoff.issue_title_prefix + '`'] else []) +
    (if std.objectHas(handoff, 'labels') then ['- `labels`: ' + std.join(', ', handoff.labels)] else []) +
    (if std.objectHas(handoff, 'assignees') then ['- `assignees`: ' + std.join(', ', handoff.assignees)] else []) +
    ['']
  ) +
  [
    '## Admission',
    '- `decision`: `' + admitted.admission.decision + '`',
    '- `policy_bundle_id`: `' + admitted.admission.policy_bundle_id + '`',
    '- `admitted_at`: `' + admitted.admission.admitted_at + '`',
    '',
    '## Notes',
    '- Rendered from admitted `problem_set` state only.',
    '- Runtime actors remain derived operators after admission.',
    '',
  ]
)
