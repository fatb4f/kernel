# Canonical Shell/CLI -> Bashly Crosswalk

This crosswalk keeps the canonical semantic model as authority and treats Bashly as a projection target.

The companion machine-readable adapter contract is:
- `bashly_projection_matrix.v1.json`

## Authority Split

| Layer | Authority status | Bashly surface |
| --- | --- | --- |
| Canonical semantic objects and relations | Authoritative | Not a Bashly file |
| Implementation projection | Projected | `bashly.yml` under `bashly.json` |
| Adapter controls | Projected, non-authoritative | `settings.yml` / `bashly-settings.yml` under `settings.json` |
| Emitted help/runtime text overrides | Projected, non-authoritative | `bashly-strings.yml` under `strings.json` |

That separation is reinforced by the shell/CLI extension profile and extension constraints:
- shell assets remain projection-only
- implementation backends are projection targets
- verification backends are projection consumers

## Crosswalk by Semantic Role

| Canonical semantic role | Canonical object kind | Required canonical attributes | Bashly target surface | Bashly primitive | Typical Bashly fields | Lossiness | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `command_surface` | `artifact_target` | `command_path`, `handler_id`, `entry_surface` | `bashly.json` | `command` | `name`, `commands[].name`, `commands[].alias`, `commands[].help`, `commands[].group`, `commands[].default`, `commands[].filename` | Partial | Nested-command structure maps well; some command-node constraints remain Bashly-specific. |
| `parameter_surface` with positional arg | `other` | `parameter_kind`, `command_ref` | `bashly.json` | `argument` | `args[].name`, `args[].help`, `args[].required`, `args[].default`, `args[].allowed`, `args[].validate`, `args[].repeatable` | Low | Positional ordering and optional/required sequencing must be enforced before projection. |
| `parameter_surface` with option/flag | `other` | `parameter_kind`, `command_ref` | `bashly.json` | `flag` | `flags[].long`, `flags[].short`, `flags[].help`, `flags[].arg`, `flags[].required`, `flags[].default`, `flags[].allowed`, `flags[].repeatable`, `flags[].conflicts`, `flags[].needs`, `flags[].private`, `flags[].completions`, `flags[].validate`, `flags[].unique` | Low | Canonical option/flag semantics fit here directly. |
| `environment_binding` | `other` | `env_name` | `bashly.json` | `environment_variable` | `environment_variables[].name`, `help`, `required`, `default`, `private`, `allowed`, `validate` | Low | Keep env semantics canonical; project render semantics to Bashly. |
| `dependency_requirement` | `other` | `dependency_name` | `bashly.json` | `dependency` | `dependencies`, `dependencies.<name>.command`, `dependencies.<name>.help` | Low | Alternate command forms require explicit Bashly hash syntax. |
| `usage_example` | `other` | `command_line` | `bashly.json` | `example` | `examples` | Low | Bind examples to owning command node. |
| `output_contract` | `policy` | `output_mode` | `settings.json` indirectly | `settings_contract` | `show_examples_on_error`, `formatter`, `env` | Partial | Structured output is not a native Bashly semantic primitive; keep it canonical and let it influence adapter settings or generated code conventions only. |
| `verification_expectation` | `other` | `expectation_kind` | none direct | none | none | High | Do not push into Bashly config; project separately to Bats or ShellSpec. |
| `projection_adapter_settings` | `policy` | none | `settings.json` | `settings` | `compact_short_flags`, `conjoined_flag_args`, `private_reveal_key`, `usage_colors`, `formatter`, `env` | Low | Adapter-only; not domain authority. |
| `usage_and_error_strings` | `policy` | none | `strings.json` | `strings_override` | `usage`, `options`, `arguments`, `commands`, `examples`, `environment_variables`, `validation_errors`, `dependency_errors` | Partial | Presentation/runtime text only. |

This crosswalk is aligned with `bashly_projection_matrix.v1.json`.

## Concrete Mapping Rules

### 1. Promote only these roles into `bashly.yml`

These are first-class Bashly projections:
- command surface
- positional args
- flags/options
- environment bindings
- dependencies
- examples

### 2. Keep these out of `bashly.yml`

These stay outside Bashly’s authority lane:
- output contracts
- verification expectations
- broader projection policy
- shell asset lineage and proposal governance

Those belong in the canonical model, extension profile, constraint layer, and projection manifest.

### 3. Treat Bashly settings as adapter controls

Use `settings.yml` only for projection behavior such as formatting, interface toggles, aliases, and generation-time modifiers.

Do not allow settings to become semantic authority.

### 4. Treat Bashly strings as presentation

Use `bashly-strings.yml` only for emitted labels and runtime/help text.

Do not let strings back-author semantics already present in canonical metadata.

## Minimal Canonical -> Bashly Field Map

### Command surface

Canonical shape:

```json
{
  "shell_cli_role": "command_surface",
  "command_path": ["control-plane", "bootstrap"],
  "handler_id": "bootstrap_control_plane_project"
}
```

Projects roughly to:

```yaml
name: control-plane
commands:
  - name: bootstrap
    filename: bootstrap_control_plane_project
```

### Option / flag surface

Canonical shape:

```json
{
  "shell_cli_role": "parameter_surface",
  "parameter_kind": "option",
  "command_ref": "object:control_plane_bootstrap_command",
  "long_flag": "--owner",
  "env_binding": "OWNER"
}
```

Projects to a Bashly `flags[]` entry, with the command reference determining the owning node.

### Environment binding

Canonical shape:

```json
{
  "shell_cli_role": "environment_binding",
  "env_name": "PROJECT_TITLE"
}
```

Projects to `environment_variables[]`.

### Output contract

Canonical shape:

```json
{
  "shell_cli_role": "output_contract",
  "output_mode": "structured_preferred",
  "preferred_formats": ["json"]
}
```

This is not a Bashly CLI primitive.

Keep it canonical and let it influence:
- adapter settings where relevant
- generated code conventions where required

### Verification expectation

Canonical shape:

```json
{
  "shell_cli_role": "verification_expectation",
  "expectation_kind": "black_box_cli_contract",
  "preferred_verification_backend": "bats"
}
```

Projects to a Bats suite, not Bashly config.

## Recommended Projection Policy

### Put in canonical authority

- command identity and path
- parameter semantics
- env and dependency semantics
- output contract
- verification expectations
- target bindings and provenance

### Put in Bashly projection

- command tree
- help text
- positional args
- flags/options
- environment variable declarations
- dependency declarations
- examples

### Put in Bashly settings

- generator controls
- formatter choices
- interface toggles
- environment-specific generation options

### Put in Bashly strings

- usage labels
- validation and dependency error phrasing
- help captions

## Resulting First-Slice Operating Rule

For the Bashly and Bats slice:

1. Author shell/CLI semantics in the canonical model.
2. Enforce shell-role constraints through the extension constraint layer.
3. Project implementation semantics to Bashly config.
4. Project verification semantics to Bats.
5. Record produced artifacts in the projection manifest.
