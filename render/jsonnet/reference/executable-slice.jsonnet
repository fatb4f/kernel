local admitted = std.extVar('admitted_state');

local render_sources(section) =
  std.join('\n', std.map(function(ref) '- `' + ref + '`', section.source_refs));

local render_section(section) =
  '## ' + section.title + '\n\n' +
  section.summary + '\n\n' +
  'Sources:\n' +
  render_sources(section) + '\n';

{
  'generated/docs/reference/executable-slice.md':
    '# Executable Reference Slice\n\n' +
    'This page is derived from admitted state for `reference-docs-executable-slice`.\n\n' +
    '## Render Contract\n\n' +
    '- renderer: `' + admitted.render_contract.renderer + '`\n' +
    '- runtime: `' + admitted.render_contract.runtime + '`\n' +
    '- input_class: `' + admitted.render_contract.input_class + '`\n' +
    '- output_class: `' + admitted.render_contract.output_class + '`\n' +
    '- output_path: `' + admitted.output_path + '`\n\n' +
    '## Gate Model\n\n' +
    std.join('\n', std.map(function(gate) '- `' + gate + '`', admitted.gate_model)) + '\n\n' +
    std.join('\n', std.map(render_section, admitted.sections)),
}
