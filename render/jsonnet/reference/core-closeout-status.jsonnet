local admitted = std.extVar('admitted_state');

local bullet(items) = std.join('\n', std.map(function(item) '- `' + item + '`', items));

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
bullet(admitted.blockers) + '\n\n' +
'## Status rule\n\n' +
'The core kernel operational status remains not closed until the closeout manifest criteria are satisfied across the broader kernel surface.\n'
