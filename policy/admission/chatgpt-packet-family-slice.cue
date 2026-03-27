package admission

#SchemaRole: "authority_manifest" | "packet_definition" | "scm_pattern_binding" | "packet_review_request" | "packet_review_decision" | "root_trust_evidence" | "regen_record" | "artifact_manifest" | "packet_approval"
#EntryStatus: "materialized"

#Entry: {
  schema_id:             string
  schema_role:           #SchemaRole
  schema_ref:            string
  workflow_binding_refs: [...string] & [string, ...string]
  source_refs:           [...string] & [string, ...string]
  summary:               string
  status:                #EntryStatus
}

#Normalized: {
  kind:              "kernel.chatgpt_packet_family.slice_input"
  control_object_id: "chatgpt-packet-family-slice"
  registry_id:       "kernel-chatgpt-packet-family"
  family_root:       "generated/schemas/chatgpt-pipeline/packet"
  source_module_id:  "chatgpt-packet-family-slice"
  source_module_ref: "structures/core/chatgpt-packet-family-slice.module.json"
  export_schema_ref: "schemas/exported/chatgpt-packet-family-slice-input.schema.json"
  generator_ref:     "manifests/generators/chatgpt-packet-family-slice.generator.json"
  projection_ref:    "manifests/projections/chatgpt-packet-family-slice.projection.json"
  output_path:       "generated/registries/chatgpt-packet-family.index.json"
  approval_state:    "APPROVED"
  entries:           [...#Entry] & [#Entry, ...#Entry]
  render_contract: {
    renderer:     "jsonnet"
    input_class:  "admitted_state"
    output_class: "registry"
    runtime:      string
    runtime_path: string
  }
}
