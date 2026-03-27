local admitted = std.extVar('admitted_state');

local bullet(items) = std.join('\n', std.map(function(item) '- `' + item + '`', items));
local blockerSection = if std.length(admitted.blockers) == 0 then 'None.\n' else bullet(admitted.blockers) + '\n';
local statusRule = if admitted.current_status == 'OPEN'
  then 'The core kernel operational status is open because the closeout manifest criteria are satisfied on record.\n'
  else 'The core kernel operational status remains not closed until the closeout manifest criteria are satisfied across the broader kernel surface.\n';

'# Operational Status\n\n' +
'Current baseline status for the kernel-spec-defined workflow:\n\n' +
'- `' + admitted.current_status + '`\n\n' +
'## Why\n\n' +
admitted.status_explanation + '\n\n' +
'## What is true\n\n' +
bullet(admitted.implemented_slices) + '\n\n' +
'## Decision basis\n\n' +
bullet(admitted.decision_basis) + '\n\n' +
'## What is blocking status closure\n\n' +
blockerSection + '\n' +
'## Status rule\n\n' +
statusRule
