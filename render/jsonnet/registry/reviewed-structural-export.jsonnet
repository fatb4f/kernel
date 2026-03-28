local admitted = std.extVar('admitted_state');
local exportInput = std.extVar('export_slice_input');
local schemaRef = std.extVar('schema_base_ref');
local manifestRef = std.extVar('constraints_manifest_ref');
local preservationRef = std.extVar('constraint_preservation_report_ref');

{
  artifact_type: 'kernel.reviewed_structural_export_registry',
  artifact_version: '0.1.0',
  contract_id: admitted.contract_id,
  title: admitted.title,
  source_admitted_state_ref: exportInput.source_admitted_state_ref,
  output_bundle: {
    schema_base_ref: schemaRef,
    constraints_manifest_ref: manifestRef,
    constraint_preservation_report_ref: preservationRef,
  },
  structures: [
    {
      name: structure.name,
      kind: structure.kind,
      field_count: std.length(structure.fields),
    }
    for structure in admitted.structures
  ],
  constraints: [
    {
      id: constraint.id,
      constraint_class: constraint.constraint_class,
      preservation_mode: if std.objectHas(constraint, 'preservation_mode')
        then constraint.preservation_mode
        else 'externalized',
    }
    for constraint in exportInput.constraints
  ],
  generated_from: {
    control_object_id: 'reviewed-structural-export-slice',
    output_path: 'generated/registries/reviewed-structural-export.index.json',
  },
}
