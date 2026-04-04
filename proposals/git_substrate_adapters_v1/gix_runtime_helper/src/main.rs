use std::{env, fs, path::PathBuf};

use anyhow::{bail, Context, Result};
use gix::{
    bstr::{BStr, BString},
    object::tree::diff::ChangeDetached,
    progress,
    status::Item as StatusItem,
};
use serde::Serialize;

#[derive(Debug)]
struct Args {
    repo_path: PathBuf,
    comparison_ref: String,
    output_root: PathBuf,
}

#[derive(Serialize)]
struct ChangedFile {
    status: String,
    path: String,
}

#[derive(Serialize)]
struct GixProjection {
    repository_path: String,
    head: String,
    branch: String,
    clean: bool,
    status_entries: Vec<String>,
    comparison_ref: String,
    comparison_base: String,
    changed_files: Vec<ChangedFile>,
    file_count: usize,
    numstat: Vec<serde_json::Value>,
}

fn main() -> Result<()> {
    let args = parse_args()?;
    let projection = emit_projection(&args)?;
    fs::create_dir_all(&args.output_root)
        .with_context(|| format!("create output root {}", args.output_root.display()))?;
    let output_path = args.output_root.join("gix_projection.json");
    fs::write(&output_path, serde_json::to_vec_pretty(&projection)?)
        .with_context(|| format!("write {}", output_path.display()))?;
    println!("{}", serde_json::to_string_pretty(&projection)?);
    Ok(())
}

fn parse_args() -> Result<Args> {
    let mut repo_path: Option<PathBuf> = None;
    let mut comparison_ref: Option<String> = None;
    let mut output_root: Option<PathBuf> = None;
    let mut it = env::args().skip(1);

    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--repo-path" => repo_path = it.next().map(PathBuf::from),
            "--comparison-ref" => comparison_ref = it.next(),
            "--output-root" => output_root = it.next().map(PathBuf::from),
            "--help" | "-h" => {
                print_help();
                std::process::exit(0);
            }
            other => bail!("unexpected argument: {other}"),
        }
    }

    Ok(Args {
        repo_path: repo_path.context("--repo-path is required")?,
        comparison_ref: comparison_ref.context("--comparison-ref is required")?,
        output_root: output_root.context("--output-root is required")?,
    })
}

fn print_help() {
    eprintln!("Usage: gix_runtime_helper --repo-path <path> --comparison-ref <ref> --output-root <path>");
}

fn emit_projection(args: &Args) -> Result<GixProjection> {
    let repo = gix::discover(&args.repo_path)
        .with_context(|| format!("discover repository at {}", args.repo_path.display()))?;
    let head_id = repo.head_id().context("resolve HEAD id")?.detach();
    let branch = repo
        .head_name()
        .context("resolve HEAD name")?
        .map(|name| shorten_ref_name(&name.to_string()))
        .unwrap_or_else(|| "HEAD".to_string());

    let status_entries = collect_status_entries(&repo)?;
    let comparison_id = repo
        .rev_parse_single(args.comparison_ref.as_str())
        .with_context(|| format!("resolve comparison ref {}", args.comparison_ref))?
        .detach();
    let comparison_base = repo
        .merge_base(head_id, comparison_id)
        .with_context(|| format!("compute merge-base for HEAD and {}", args.comparison_ref))?
        .detach();

    let old_tree = repo
        .find_commit(comparison_base)
        .context("find comparison-base commit")?
        .tree()
        .context("resolve comparison-base tree")?;
    let new_tree = repo
        .find_commit(head_id)
        .context("find HEAD commit")?
        .tree()
        .context("resolve HEAD tree")?;

    let changed_files = repo
        .diff_tree_to_tree(Some(&old_tree), Some(&new_tree), None)
        .context("diff trees with gix")?
        .into_iter()
        .map(change_to_changed_file)
        .collect::<Vec<_>>();

    Ok(GixProjection {
        repository_path: args.repo_path.display().to_string(),
        head: head_id.to_string(),
        branch,
        clean: status_entries.is_empty(),
        status_entries,
        comparison_ref: args.comparison_ref.clone(),
        comparison_base: comparison_base.to_string(),
        file_count: changed_files.len(),
        changed_files,
        numstat: Vec::new(),
    })
}

fn collect_status_entries(repo: &gix::Repository) -> Result<Vec<String>> {
    let iter = repo
        .status(progress::Discard)
        .context("prepare status platform")?
        .into_iter(Vec::<BString>::new())
        .context("collect status iterator")?;
    let mut out = Vec::new();
    for item in iter {
        let item = item.context("read status item")?;
        let kind = match &item {
            StatusItem::IndexWorktree(_) => "index_worktree",
            StatusItem::TreeIndex(_) => "tree_index",
        };
        out.push(format!("{kind}\t{}", bstr_to_string(item.location())));
    }
    out.sort();
    Ok(out)
}

fn change_to_changed_file(change: ChangeDetached) -> ChangedFile {
    match change {
        ChangeDetached::Addition { location, .. } => ChangedFile {
            status: "A".to_string(),
            path: bstring_to_string(location),
        },
        ChangeDetached::Deletion { location, .. } => ChangedFile {
            status: "D".to_string(),
            path: bstring_to_string(location),
        },
        ChangeDetached::Modification { location, .. } => ChangedFile {
            status: "M".to_string(),
            path: bstring_to_string(location),
        },
        ChangeDetached::Rewrite { copy, location, .. } => ChangedFile {
            status: if copy { "C" } else { "R" }.to_string(),
            path: bstring_to_string(location),
        },
    }
}

fn bstr_to_string(input: &BStr) -> String {
    String::from_utf8_lossy(input.as_ref()).into_owned()
}

fn bstring_to_string(input: BString) -> String {
    String::from_utf8_lossy(input.as_ref()).into_owned()
}

fn shorten_ref_name(name: &str) -> String {
    name.strip_prefix("refs/heads/")
        .or_else(|| name.strip_prefix("refs/remotes/"))
        .unwrap_or(name)
        .to_string()
}
