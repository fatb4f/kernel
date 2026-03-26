{
  title: "Kernel Reference Workflow",
  source_of_truth: [
    "kernel.spec.md",
    "kernel.spec.json"
  ],
  render_contract: {
    renderer: "Jsonnet",
    input_class: "admitted state",
    output_class: "reference documentation"
  },
  pages: [
    {
      path: "generated/docs/reference/README.md",
      title: "Reference Workflow",
      purpose: "Entry point for the downstream operational workflow docs."
    },
    {
      path: "generated/docs/reference/workflow.md",
      title: "Workflow",
      purpose: "Explain the four-state kernel pipeline and plane boundaries."
    },
    {
      path: "generated/docs/reference/gates.md",
      title: "Gates",
      purpose: "Summarize the gate model and required evidence."
    },
    {
      path: "generated/docs/reference/admission-artifacts.md",
      title: "Admission Artifacts",
      purpose: "Describe the admission output location and minimum semantics."
    }
  ]
}
