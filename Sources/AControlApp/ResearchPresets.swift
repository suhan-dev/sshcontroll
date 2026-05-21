import Foundation
import SwiftUI

struct CodexPluginSnippet: Identifiable, Hashable {
  var id: String { title + "\n" + snippet }
  var title: String
  var snippet: String
  var category = "Tools"
  var symbol = "puzzlepiece.extension"
  var detail = ""
}

struct CodexResearchPreset: Identifiable, Hashable {
  static let defaultLoopCount = 6
  static let loopCountChoices = [1, 3, 6, 9]
  static let maxLoopCount = 9

  var id: String
  var title: String
  var subtitle: String
  var symbol: String
  var domainBrief: String
  var outputFocus: String

  func prompts(
    sessionName: String,
    sessionDir: String,
    pluginContext: String,
    seedPrompt: String = "",
    loopCount requestedLoopCount: Int = Self.defaultLoopCount,
    groupID: String = "research-run"
  ) -> [String] {
    let total = Self.clampedLoopCount(requestedLoopCount)
    let labPath = "research_loops/\(id)/\(groupID)"
    let programOS = Self.programOperatingSystem(labPath: labPath, presetTitle: title)
    let researchRequest =
      seedPrompt.trimmed.isEmpty
      ? "Use the active session, repository files, recent transcript, and existing artifacts to choose the strongest research objective."
      : seedPrompt.trimmed
    if id == "peer-review-lab" {
      return peerReviewLabPrompts(
        sessionName: sessionName,
        sessionDir: sessionDir,
        pluginContext: pluginContext,
        researchRequest: researchRequest,
        requestedLoopCount: total,
        labPath: labPath,
        programOS: programOS
      )
    }
    if id == "nature-referee-board" {
      return natureRefereeBoardPrompts(
        sessionName: sessionName,
        sessionDir: sessionDir,
        pluginContext: pluginContext,
        researchRequest: researchRequest,
        requestedLoopCount: total,
        labPath: labPath,
        programOS: programOS
      )
    }
    let header = """
      Research preset: \(title)
      Active session: \(sessionName)
      Working directory: \(sessionDir)
      Requested autonomous depth: \(total)
      Durable lab path: \(labPath)

      User research request:
      \(researchRequest)

      You are not a short-answer assistant. Act like a persistent senior researcher.
      Use substantial reasoning and token budget. Do not stop after one plausible answer or one small patch.
      Run multiple research cycles: propose, derive, test, attack, revise, and document.
      Do not ask the user before doing ordinary research work. If a path is blocked, write the blocker and continue with the strongest adjacent calculation.
      Treat each queued stage as a real work session, not a chat reply. If the obvious task ends quickly, continue into the next highest-value analysis inside the same stage.
      Keep the visible transcript readable, but make the durable artifacts detailed enough that a future researcher can resume without guessing.
      Research tempo: do not rush. Treat each stage like a serious professor/researcher work block. Before finishing a stage, produce either a meaningful artifact, a reproducible calculation, a decisive counterexample, or a clearly documented blocker with the next best route.
      For long runs, keep expanding the research frontier instead of repeatedly summarizing. Read what previous stages produced, correct mistakes, and continue from the strongest surviving direction.
      Professor mode: behave like the PI of a small research group. Maintain a research notebook, identify the central Hamiltonian/Lagrangian/object of study when relevant, define observables, isolate symmetries and approximations, compare analytic and numerical evidence, and leave the next researcher with exact commands and file paths.
      Do not finish a stage simply because a coherent paragraph exists. If the answer looks quick, spend the remaining effort on a harder check: a limiting case, a gauge/phase convention audit, a null model, a convergence test, a literature/tool cross-check, or an improved figure/table.
      Time allocation: each stage should feel like a deep work block, not a status update. Spend real effort reading files, running/checking artifacts, and writing durable outputs before the visible response. The last third of a multi-stage run must be production-heavy: create/refine reports, figures, simulations, UI, slides, or reproducible packages instead of merely planning more work.

      Long-horizon research contract:
      - Treat this as a serious lab session that may run for hours, not as a single chat answer.
      - Never declare a stage complete until the Research Completion Gate below is satisfied.
      - If a prompt looks solved in minutes, use the remaining effort to deepen the work: derive a stronger theorem, search for a counterexample, build a more decisive experiment, or improve the research artifact.
      - Prefer creating a durable theory, design principle, benchmark, report section, simulator, or reproducible script over answering conversationally.
      - Make new ideas explicit. Label each new mechanism, hypothesis, design principle, or theory contribution with an ID so future stages can attack or extend it.
      - The queued stages are not repeats. Each stage has a different mandate and must leave a different kind of artifact.
      - If the current stage feels similar to a previous stage, stop and specialize it: change the observable, model level, evidence source, reviewer role, failure mode, or artifact type.
      - In 6-stage and 9-stage runs, stages in the final third must create polished artifacts or run decisive checks. They are not allowed to end as "next steps" only.

      Workflow handoff contract:
      - Each stage must read the previous stage's HANDOFF.md or NEXT_STAGE.md when it exists.
      - Each stage must write its own handoff file before ending, with exact files changed, claims promoted/demoted, unresolved blockers, and the next stage's marching orders.
      - Do not repeat a previous stage. If the next instruction looks similar, advance the same research thread with stronger evidence, a sharper counterexample, or a concrete artifact.
      - The visible transcript should be compact. The durable files should carry the detail.

      Research Program OS:
      \(programOS)

      Parallel Professor Lab protocol:
      - Treat the main Codex run as the Professor Orchestrator, not as a lone chat reply.
      - If the runtime exposes subagents or parallel agents, spawn independent agents immediately and let them work in parallel while you inspect the repository yourself.
      - Use these role lanes by default: Theory PI, Computation/Numerics, Literature & Tools, Skeptical Referee, and Synthesis Editor.
      - Assign disjoint write ownership so parallel work does not collide:
        Theory PI writes under \(labPath)/roles/theory/
        Computation/Numerics writes under \(labPath)/roles/numerics/
        Literature & Tools writes under \(labPath)/roles/literature/
        Skeptical Referee writes under \(labPath)/roles/referee/
        Synthesis Editor writes under \(labPath)/synthesis/
      - While subagents run, the Professor Orchestrator must do non-overlapping local work: read key files, build the claim map, identify missing evidence, and prepare the integration plan.
      - Wait for role results when needed, then integrate them into one coherent research record. Do not paste role outputs side by side without resolving contradictions.
      - If subagents are unavailable, emulate the same roles serially, but keep the role notes separated in the same directories.
      - Never let role work remain isolated. Every stage must update the program board, claim ledger, and next-decision queue.

      Depth contract:
      - First inspect the active files, recent transcript context, and existing artifacts before choosing an angle.
      - Do at least three passes: construction, adversarial critique, and repair/synthesis.
      - Prefer a concrete equation, script, figure, table, benchmark, or edited file over a pure explanation.
      - When using computation, include baseline, null/control, stress case, and a reproducible command where possible.
      - When using literature or plugins, cite what was checked and separate tool-dependent evidence from analytic evidence.
      - Update or create a durable research log under \(labPath)/ with decisions, failures, and next actions.
      - End with a compact transcript summary plus exact file paths touched or created.
      - If a relevant plugin is available, use it. If a clearly relevant plugin is missing, state the missing plugin and continue with the best local method rather than stopping.
      - Minimum stage budget: before ending, complete at least two concrete work blocks from this list: file/artifact inspection, derivation/model update, command/test/simulation, figure/table/report edit, design/UI verification, or independent referee critique. If only one block was possible, write the exact blocker and perform the next best adjacent block.

      Research Completion Gate:
      Before ending each stage, verify that at least four of these are true:
      - A claim, model, design rule, or research question was made sharper than at stage start.
      - A concrete artifact was created or improved under \(labPath)/ or the active project.
      - A calculation, test, benchmark, literature/tool check, or screenshot/render review was performed or specified with exact commands.
      - A serious counterargument was written and either survived as a blocker or was repaired.
      - The claim ledger, evidence matrix, or decision log changed.
      - The next stage has a precise instruction that cannot be mistaken for generic continuation.

      Domain brief:
      \(domainBrief)

      Preset-specific operating protocol:
      \(domainProtocol)

      Output focus:
      \(outputFocus)

      Available plugin/tool context:
      \(pluginContext)

      Research hygiene:
      - Mark claims as RESULT, CONJECTURE, or FAILURE.
      - Prefer files, figures, scripts, and reproducible commands over prose-only output.
      - Put durable notes under \(labPath)/ when possible.
      - Keep a concise visible progress trail in the transcript.
      - Separate analytic arguments, numerical evidence, and literature/tool-dependent evidence.
      - Be willing to downgrade a beautiful idea if the math or evidence does not survive.
      - Keep an index. If more than three files are created, update \(labPath)/ARTIFACT_INDEX.md.
      """

    return expertStagePrompts(total: total, header: header, labPath: labPath)
  }

  private func expertStagePrompts(total: Int, header: String, labPath: String) -> [String] {
    let stages: [(title: String, objective: String, antiBias: String, deliverables: String)]
    switch total {
    case 1:
      stages = [
        (
          "expert sprint with sealed mini-board",
          """
          Run the whole expert workflow inside one serious stage. This is not a quick answer.
          First build a neutral dossier from the active files/transcript/artifacts. Then create at least three separated role notes: PI Builder, Evidence/Computation Lead, and Harsh Referee. If subagents are available, spawn those roles with disjoint write paths; if not, emulate them in separated files before synthesis. Only after those role notes exist, integrate them into one expert decision.
          Push beyond a plan: perform one concrete derivation, verification command, artifact inspection, script edit, figure/table audit, or UI/runtime check that changes the state of the project.
          """,
          """
          Bias firewall:
          - Write role notes before writing the synthesis. Do not let the Synthesis Editor read its own conclusion as evidence.
          - Label every important claim RESULT, CONJECTURE, FAILURE, or NOT_CHECKED.
          - Include one strongest counterexample or failure mode and decide whether it survives.
          - If a source, plugin, or file was not inspected, say NOT_CHECKED rather than inventing certainty.
          """,
          """
          Deliver:
          - \(labPath)/PROGRAM.md
          - \(labPath)/roles/pi_builder/REPORT.md
          - \(labPath)/roles/evidence_lead/REPORT.md
          - \(labPath)/roles/harsh_referee/REPORT.md
          - \(labPath)/EXPERT_SYNTHESIS.md
          - \(labPath)/CLAIM_LEDGER.csv
          - \(labPath)/EVIDENCE_MATRIX.md
          - \(labPath)/ARTIFACT_INDEX.md
          - \(labPath)/NEXT_STAGE.md with the exact next expert task.
          """
        )
      ]
    case 3:
      stages = [
        (
          "dossier, role split, and research contract",
          """
          Build the research dossier and split the work into independent lanes. Decide the central object of study, observables, assumptions, known artifacts, missing evidence, and the strongest publishable/product claim. Create sealed role directories before doing synthesis.
          """,
          """
          Bias firewall:
          - Separate "what the project claims" from "what files prove."
          - Create a self-bias note listing attractive ideas you are not allowed to assume.
          - Define failure tests before proposing success.
          """,
          """
          Deliver:
          - \(labPath)/PROGRAM.md
          - \(labPath)/FRONTIER_MAP.md
          - \(labPath)/CLAIM_LEDGER.csv
          - \(labPath)/OPEN_PROBLEMS.md
          - \(labPath)/roles/README.md with role boundaries.
          - \(labPath)/HANDOFF.md for stage 2.
          """
        ),
        (
          "independent evidence lanes and primary test",
          """
          Read stage 1 outputs. Run the most decision-changing evidence pass. Depending on domain, this means a derivation, parameter sweep, reproducibility command, artifact preview check, UI latency check, DFT convergence audit, or design verification. Keep Theory/Build, Evidence/Computation, and Referee notes separated until all three have a conclusion.
          """,
          """
          Bias firewall:
          - The Referee lane must attack the Evidence lane before synthesis.
          - Include baseline, null/control, and stress case when computation or UI testing is possible.
          - Downgrade claims that only have transcript evidence.
          """,
          """
          Deliver:
          - \(labPath)/roles/theory_or_build/REPORT.md
          - \(labPath)/roles/evidence_or_computation/REPORT.md
          - \(labPath)/roles/referee/REPORT.md
          - \(labPath)/EVIDENCE_MATRIX.md updated.
          - A script, table, screenshot note, command log, or exact blocker that changes the evidence.
          - \(labPath)/HANDOFF.md for stage 3.
          """
        ),
        (
          "professor synthesis, revision, and next research queue",
          """
          Read the separated role outputs. Resolve contradictions, revise the strongest artifact or report if safe, and produce the final professor decision. The result must be one coherent research record, not pasted role reports.
          """,
          """
          Bias firewall:
          - The final decision must list what changed its mind.
          - No claim may be RESULT without evidence path plus failure test.
          - Preserve rejected ideas in a killed-claims section so they do not reappear as fresh insights.
          """,
          """
          Deliver:
          - \(labPath)/PROFESSOR_DECISION.md
          - \(labPath)/REVISION_OR_IMPLEMENTATION_LOG.md
          - \(labPath)/NEXT_AGENT_PROMPTS.md
          - \(labPath)/LONG_RUN_PLAN.md
          - \(labPath)/ARTIFACT_INDEX.md updated.
          - A compact transcript summary with exact changed/created files.
          """
        ),
      ]
    case 6:
      stages = [
        (
          "program charter and evidence map",
          """
          Build the full research operating system. Inspect active files, transcript, generated artifacts, and plugin availability. Define the central question, claim ledger, evidence hierarchy, artifact index, and role plan.
          """,
          """
          Bias firewall:
          - Separate raw artifacts from interpretation.
          - Define at least three ways the central claim could fail.
          - Create independent role paths before any synthesis.
          """,
          """
          Deliver:
          - \(labPath)/PROGRAM.md
          - \(labPath)/FRONTIER_MAP.md
          - \(labPath)/CLAIM_LEDGER.csv
          - \(labPath)/EVIDENCE_MATRIX.md
          - \(labPath)/ARTIFACT_INDEX.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "minimal model, architecture, or design theory",
          """
          Build the smallest model that can carry the claim. For physics, derive the Hamiltonian/Lagrangian/dynamical matrix, observables, symmetries, topology/geometric phase hooks, and limiting cases. For app/design/report domains, derive the state model, workflow invariants, acceptance criteria, and reviewer-facing thesis.
          """,
          """
          Bias firewall:
          - Write assumptions and units/invariants before conclusions.
          - Include one theorem-like conjecture, design invariant, or model prediction plus a counterexample.
          - Kill or downgrade at least one weak claim if it does not survive.
          """,
          """
          Deliver:
          - \(labPath)/01_minimal_model.md
          - \(labPath)/ASSUMPTION_LEDGER.md
          - \(labPath)/THEORY_INCUBATOR.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "evidence campaign and concrete experiment",
          """
          Execute or specify the most useful calculation, simulation, UI/runtime test, DFT audit, report artifact check, or design verification. Prefer reproducible commands and generated artifacts over prose.
          """,
          """
          Bias firewall:
          - Include baseline, null/control, and stress case where possible.
          - Record exact commands, files, and blockers.
          - Distinguish evidence-grade outputs from exploratory outputs.
          """,
          """
          Deliver:
          - \(labPath)/02_evidence_campaign.md
          - \(labPath)/experiments/COMPUTE_OR_QA_MANIFEST.md
          - A script, command log, figure/table, screenshot QA note, or exact blocker.
          - \(labPath)/EVIDENCE_MATRIX.md updated.
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "sealed skeptical review",
          """
          Act as an independent referee. Read prior outputs and raw artifacts, then attack them. Look for hallucinated citations, stale previews, gauge/basis mistakes, hidden assumptions, bad controls, units/sign errors, UX state bugs, unsupported report claims, or duplicated narrative.
          """,
          """
          Bias firewall:
          - Write the referee report before writing any repair plan.
          - No polite summary. Find the strongest real objection.
          - Downgrade the ledger honestly.
          """,
          """
          Deliver:
          - \(labPath)/roles/referee/SEALED_REVIEW.md
          - \(labPath)/REFEREE_GATE.md
          - \(labPath)/REJECTED_OR_DOWNGRADED_CLAIMS.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "repair, synthesis, and artifact upgrade",
          """
          Read the referee output, repair what can be repaired, and improve the strongest artifact. This may mean editing a report, regenerating a figure, tightening a derivation, fixing code, or creating a clearer design/implementation note.
          """,
          """
          Bias firewall:
          - Every repaired claim must cite the evidence that changed.
          - Do not hide blockers. Turn them into next tests.
          - Prefer one decisive improvement over many cosmetic notes.
          """,
          """
          Deliver:
          - \(labPath)/04_synthesis.md
          - \(labPath)/REVISION_LOG.md
          - \(labPath)/manuscript/OUTLINE.md or product/design equivalent.
          - Updated project files when safe.
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "final professor gate and long-run plan",
          """
          Act as the professor/editor. Decide what is now known, what remains speculative, and what should run next. Produce a durable queue that can continue all day without repeating generic prompts.
          """,
          """
          Bias firewall:
          - State what would change the conclusion.
          - Require exact next artifacts and failure criteria.
          - Keep the transcript compact and make files carry the detail.
          """,
          """
          Deliver:
          - \(labPath)/PROFESSOR_DECISION.md
          - \(labPath)/NEXT_AGENT_PROMPTS.md
          - \(labPath)/LONG_RUN_PLAN.md
          - \(labPath)/SEMINAR_AGENDA.md
          - \(labPath)/ARTIFACT_INDEX.md updated.
          """
        ),
      ]
    default:
      stages = [
        (
          "orchestrator dossier and sealed lane setup",
          """
          Build the dossier, decide the research objective, create the role directories, and write the rules that prevent later stages from copying each other's conclusions. The visible conversation should stay one thread, but the work must be separated into role files.
          """,
          """
          Bias firewall:
          - Establish sealed lanes: theory/build, computation/evidence, literature/tools, skeptical referee, synthesis editor.
          - Define claims, observables, and failure tests before evidence collection.
          """,
          """
          Deliver:
          - \(labPath)/PROGRAM.md
          - \(labPath)/CLAIM_LEDGER.csv
          - \(labPath)/EVIDENCE_MATRIX.md
          - \(labPath)/roles/README.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "Theory PI or architecture lead",
          """
          Work only as the theory/architecture/design-system lead. Formalize the model, assumptions, invariants, equations, state machine, or design thesis. Do not synthesize other lanes yet.
          """,
          """
          Bias firewall:
          - Do not claim evidence that this lane did not inspect.
          - Include one attractive idea and one reason it may be wrong.
          """,
          """
          Deliver:
          - \(labPath)/roles/theory/REPORT.md
          - \(labPath)/roles/theory/ASSUMPTIONS.md
          - \(labPath)/roles/theory/FAILURE_TESTS.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "Computation, implementation, or evidence lead",
          """
          Work only as the evidence lead. Run or design the decisive check: calculation, simulation, reproducibility command, installed-app/UI test, DFT convergence audit, artifact render, or data validation.
          """,
          """
          Bias firewall:
          - Include baseline/null/stress cases where possible.
          - Log commands and outputs, not just conclusions.
          """,
          """
          Deliver:
          - \(labPath)/roles/evidence/REPORT.md
          - \(labPath)/roles/evidence/COMMAND_LOG.md
          - Generated scripts/tables/figures/QA notes when feasible.
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "Literature, plugin, and prior-art scout",
          """
          Work as the source/prior-art/tooling lane. Use available plugins only when they change a decision. Audit whether the project is reinventing a known idea, missing a standard control, or using the wrong tool.
          """,
          """
          Bias firewall:
          - Mark unavailable searches as missing, not as negative evidence.
          - Separate source-dependent claims from analytic/project evidence.
          """,
          """
          Deliver:
          - \(labPath)/roles/literature/REPORT.md
          - \(labPath)/roles/literature/NOVELTY_OR_TOOL_MATRIX.md
          - \(labPath)/PLUGIN_AUDIT.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "sealed skeptical referee",
          """
          Work as the independent critic. Attack the strongest claims and the cleanest artifacts. Search for hallucinations, stale files, wrong paths, weak controls, hidden assumptions, overclaiming, and presentation drift.
          """,
          """
          Bias firewall:
          - Write the attack before repair.
          - Use RESULT/CONJECTURE/FAILURE/NOT_CHECKED labels.
          """,
          """
          Deliver:
          - \(labPath)/roles/referee/SEALED_REVIEW.md
          - \(labPath)/REFEREE_GATE.md
          - \(labPath)/REJECTED_OR_DOWNGRADED_CLAIMS.md
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "first synthesis and contradiction resolver",
          """
          Now read all role outputs. Resolve contradictions, update the ledger, and decide which direction deserves repair or implementation. Do not paste reports together.
          """,
          """
          Bias firewall:
          - Every promoted claim must cite the lane and evidence that support it.
          - Every contradiction must be resolved, downgraded, or assigned a test.
          """,
          """
          Deliver:
          - \(labPath)/SYNTHESIS_ROUND1.md
          - \(labPath)/CLAIM_LEDGER.csv updated.
          - \(labPath)/EVIDENCE_MATRIX.md updated.
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "production robustness campaign",
          """
          Do not merely review earlier work. Spend this stage producing new evidence or hardening the strongest surviving artifact. If it is an app/design task, verify the real installed UI or generated artifact and patch the most important friction. If it is physics/DFT/simulation, run or script a convergence, perturbation, gauge, seed, null, or scaling check. If it is a report/presentation, inspect the actual output and improve a figure/table/section.
          """,
          """
          Bias firewall:
          - Failure to reproduce is a result, not an inconvenience.
          - Do not rely on stage 6's prose; inspect artifacts and commands directly.
          - A plan without a produced artifact is insufficient unless the execution blocker is external and precisely documented.
          """,
          """
          Deliver:
          - \(labPath)/PRODUCTION_ROBUSTNESS.md
          - \(labPath)/experiments/round2_results_index.md
          - At least one changed script, figure/table, report/design artifact, UI patch, or an exact blocker plus a substitute artifact inspection.
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "artifact deepening and communication build",
          """
          Convert the surviving evidence into upgraded deliverables, not another outline. Write or revise the paper/report section, figure roadmap, app/design spec, DFT run sheet, simulation package, GUI plan, or slide narrative. Make it reviewer-readable and user-usable. If screenshots/PDFs/plots exist, inspect them directly and fix the clearest weakness.
          """,
          """
          Bias firewall:
          - Do not let narrative outrun evidence.
          - Include limitations and missing tests inside the artifact, not hidden in chat.
          - Make at least one artifact easier to read, reproduce, present, or run.
          """,
          """
          Deliver:
          - \(labPath)/ARTIFACT_DEEPENING.md
          - \(labPath)/manuscript/OUTLINE.md or domain equivalent.
          - \(labPath)/manuscript/FIGURE_ROADMAP.md when relevant.
          - Updated project/report/code/design files when safe, or a precise patch plan with target paths.
          - \(labPath)/HANDOFF.md
          """
        ),
        (
          "final professor production gate",
          """
          Act as PI/editor and production lead. Finish by extracting the deepest usable outputs from the whole run: final claims, downgraded claims, exact artifact paths, presentation/report readiness, and the next decisive all-day queue. If the project needs a report, GUI, slides, figure, package, or experiment plan, leave the first production version or exact executable prompt for it.
          """,
          """
          Bias firewall:
          - State what was not checked.
          - State what would change the conclusion.
          - Kill repetitive continuation prompts; each next prompt must have a distinct objective and artifact.
          - Do not end with only "future work"; end with a usable professor decision and concrete production handoff.
          """,
          """
          Deliver:
          - \(labPath)/PROFESSOR_DECISION.md
          - \(labPath)/FINAL_OUTPUTS.md with exact artifact paths and readiness status.
          - \(labPath)/ONE_DAY_RESEARCH_PLAN.md
          - \(labPath)/NEXT_AGENT_PROMPTS.md
          - \(labPath)/ARTIFACT_INDEX.md updated.
          - Compact transcript summary with exact paths.
          """
        ),
      ]
    }

    return stages.enumerated().map { index, stage in
      expertStagePrompt(
        index: index + 1,
        total: total,
        header: header,
        labPath: labPath,
        title: stage.title,
        objective: stage.objective,
        antiBias: stage.antiBias,
        deliverables: stage.deliverables
      )
    }
  }

  private func expertStagePrompt(
    index: Int,
    total: Int,
    header: String,
    labPath: String,
    title: String,
    objective: String,
    antiBias: String,
    deliverables: String
  ) -> String {
    """
    \(header)

    Stage \(index)/\(total): \(title).

    Expert-stage objective:
    \(objective)

    Stage-specific mandate:
    \(stageSpecificMandate(index: index, total: total, labPath: labPath))

    One-visible-run / multi-lane rule:
    - The user should see one coherent Codex session, but your work must use separated role files under \(labPath)/roles/ to avoid self-confirming synthesis.
    - If subagents or parallel agents are available, spawn them for independent lanes with disjoint write paths. If they are unavailable, emulate independent lanes serially and keep the notes sealed until synthesis.
    - A synthesis/editor pass may read lane outputs only after each relevant lane has written its own report.

    Hallucination and self-bias control:
    \(antiBias)

    Required working rhythm:
    1. Read the prior HANDOFF/NEXT_STAGE and the most relevant project artifacts.
    2. Spend a serious work block on the stage-specific work, creating or updating durable files before writing the final visible response.
    3. Run the strongest feasible check. If execution is blocked, write the exact command/blocker and perform a second-best inspection or artifact edit instead.
    4. Attack the result before promoting any claim.
    5. Update claim/evidence/artifact ledgers.
    6. End with a short visible summary and exact paths.
    7. If this is in the final third of the run, produce or polish at least one durable deliverable: report section, figure/table, simulation artifact, UI/design patch, slide outline, reproducible package, or final decision memo.

    \(deliverables)

    Completion gate:
    Before ending, make sure this stage produced a materially different contribution from every previous stage. If it begins to repeat prior work, stop and redirect to a new mechanism, new check, stronger counterexample, or artifact upgrade.
    """
  }

  private func stageSpecificMandate(index: Int, total: Int, labPath: String) -> String {
    let slot = canonicalStageSlot(index: index, total: total)
    switch id {
    case "deep-physics":
      return deepPhysicsMandate(slot: slot, labPath: labPath)
    case "physics-calculation":
      return physicsCalculationMandate(slot: slot, labPath: labPath)
    case "simulation-research":
      return simulationMandate(slot: slot, labPath: labPath)
    case "two-dimensional-semiconductor":
      return semiconductorMandate(slot: slot, labPath: labPath)
    case "dft-research":
      return dftMandate(slot: slot, labPath: labPath)
    case "app-development":
      return appDevelopmentMandate(slot: slot, labPath: labPath)
    case "design-research":
      return designMandate(slot: slot, labPath: labPath)
    case "research-report":
      return reportMandate(slot: slot, labPath: labPath)
    case "literature-review":
      return literatureMandate(slot: slot, labPath: labPath)
    case "theory-creation":
      return theoryMandate(slot: slot, labPath: labPath)
    default:
      return generalMandate(slot: slot, labPath: labPath)
    }
  }

  private func canonicalStageSlot(index: Int, total: Int) -> Int {
    let normalizedIndex = max(1, index)
    switch total {
    case 1:
      return 9
    case 3:
      return [1, 5, 9][min(normalizedIndex - 1, 2)]
    case 6:
      return [1, 2, 4, 5, 7, 9][min(normalizedIndex - 1, 5)]
    default:
      return min(max(normalizedIndex, 1), 9)
    }
  }

  private func generalMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return """
        Build the project dossier. Classify the workspace, identify the central question, extract existing artifacts, and create \(labPath)/PROGRAM.md plus \(labPath)/CLAIM_LEDGER.csv. Do not propose solutions until the evidence map exists.
        """
    case 2:
      return """
        Formalize the smallest model of the problem: actors, state, invariants, constraints, observables, and failure modes. Write \(labPath)/MODEL_OR_WORKFLOW.md and at least one falsifiable prediction or acceptance criterion.
        """
    case 3:
      return """
        Run the first decision-changing evidence pass. Inspect files, commands, generated artifacts, or UI/runtime behavior. Create \(labPath)/EVIDENCE_ROUND1.md with baseline, control, and blocker notes.
        """
    case 4:
      return """
        Use a source/tool lane. Check plugins, documentation, prior notes, or local references only where they change a decision. Create \(labPath)/SOURCE_AND_TOOL_AUDIT.md and mark unsupported claims NOT_CHECKED.
        """
    case 5:
      return """
        Switch to harsh referee mode. Attack the strongest attractive idea from stages 1-4. Create \(labPath)/REFEREE_GATE.md and downgrade at least one weak or under-evidenced claim if needed.
        """
    case 6:
      return """
        Repair and synthesize. Make one concrete artifact stronger: code, report prose, figure plan, experiment design, table, or theory note. Write \(labPath)/REVISION_LOG.md with exact before/after claim status.
        """
    case 7:
      return """
        Replicate or stress the surviving result. Change a parameter, model level, evidence source, UI state, data subset, or reviewer lens. Create \(labPath)/ROBUSTNESS_CHECK.md and record what would falsify the result.
        """
    case 8:
      return """
        Convert evidence into a reviewer-ready artifact. Create \(labPath)/ARTIFACT_UPGRADE.md, update \(labPath)/ARTIFACT_INDEX.md, and prepare the exact next file/report/code change.
        """
    default:
      return """
        Act as the professor/editor. Decide what is RESULT, CONJECTURE, FAILURE, and NOT_CHECKED. Produce \(labPath)/PROFESSOR_DECISION.md and \(labPath)/NEXT_AGENT_PROMPTS.md with distinct future tasks, not generic continuation.
        """
    }
  }

  private func deepPhysicsMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return """
        Physics dossier. Identify the physical degrees of freedom, state space, Hamiltonian/Lagrangian/dynamical matrix, control parameters, observables, and readout. Create \(labPath)/physics/PHYSICAL_OBJECT.md and \(labPath)/physics/OBSERVABLES.md.
        """
    case 2:
      return """
        Minimal dynamics. Derive the smallest coupled-oscillator or active-project model that can carry the claim. Track units, approximations, boundary conditions, and limiting cases in \(labPath)/physics/MINIMAL_DYNAMICS.md.
        """
    case 3:
      return """
        Topology and gauge audit. Separate geometric phase, dynamic phase, gauge convention, basis choice, edge/channel identity, winding/Chern/Zak/Berry-Hannay language, and measurable invariants. Write \(labPath)/physics/TOPOLOGY_GAUGE_AUDIT.md.
        """
    case 4:
      return """
        Quantum/classical bridge. Decide whether the mechanism is a true gate/channel/readout protocol or only an analogy. Define input/output states, fidelity/visibility, error model, and what a quantum-computing claim would require in \(labPath)/physics/QC_BRIDGE.md.
        """
    case 5:
      return """
        Mechanical chaos and control failure. Look specifically for chaos-like disadvantages of the mechanical/dynamical implementation: nonlinear actuator basins, resonant runaway, phase-slip sensitivity, hysteresis, finite-Q memory, noise-amplified mode mixing, and control-path instability. Write \(labPath)/physics/CHAOS_AND_CONTROL_RISKS.md with measurable tests.
        """
    case 6:
      return """
        Robustness campaign. Test or design tests for disorder, loss, nonadiabatic drive, finite size, boundary perturbations, readout efficiency, and parameter spread. Update \(labPath)/physics/ROBUSTNESS_MATRIX.md with RESULT/CONJECTURE/FAILURE labels.
        """
    case 7:
      return """
        Numerical or analytic stress check. Run a minimal script when possible; otherwise write a reproducible calculation plan with equations and parameters. Produce \(labPath)/physics/NUMERICAL_STRESS_CHECK.md plus any script/table created.
        """
    case 8:
      return """
        Paper-grade synthesis. Convert the surviving mechanism into a figure roadmap, theorem-like statements, limitations, and manuscript/report claims. Write \(labPath)/physics/MANUSCRIPT_PHYSICS_SECTION.md.
        """
    default:
      return """
        Professor physics decision. State the strongest new physics, the strongest failure, what remains only analogy, and the next decisive experiment. Write \(labPath)/physics/PHYSICS_PROFESSOR_DECISION.md and \(labPath)/NEXT_AGENT_PROMPTS.md.
        """
    }
  }

  private func physicsCalculationMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Define variables, units, equations, boundary conditions, and target observables in \(labPath)/calculation/PROBLEM_SETUP.md before solving."
    case 2:
      return "Derive the minimal equation set and limiting cases by hand. Save the derivation to \(labPath)/calculation/DERIVATION_CORE.md."
    case 3:
      return "Check dimensions, signs, phases, conservation laws, and basis/gauge conventions. Write \(labPath)/calculation/CONSISTENCY_AUDIT.md."
    case 4:
      return "Compute the first nontrivial approximation, perturbation, asymptotic limit, or scaling law. Record it in \(labPath)/calculation/SCALING_LAWS.md."
    case 5:
      return "Attack the result with counterexamples and singular limits. Create \(labPath)/calculation/COUNTEREXAMPLES.md."
    case 6:
      return "Pair the analytic result with a minimal numerical sanity check where feasible. Save script/output notes under \(labPath)/calculation/numerics/."
    case 7:
      return "Stress the formula against parameter changes, noise, or boundary changes. Update \(labPath)/calculation/ROBUSTNESS_TABLE.md."
    case 8:
      return "Translate the result into report-ready equations, definitions, and figure/table specs in \(labPath)/calculation/REPORT_EQUATIONS.md."
    default:
      return "Decide which formulae are RESULT, CONJECTURE, FAILURE, or NOT_CHECKED and write \(labPath)/calculation/CALCULATION_DECISION.md."
    }
  }

  private func simulationMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Define observables, parameter ranges, random seeds, baselines, null controls, and acceptance criteria in \(labPath)/simulation/SIMULATION_DESIGN.md."
    case 2:
      return "Inspect or create the minimal runnable simulation path. Record exact commands and dependencies in \(labPath)/simulation/RUN_MANIFEST.md."
    case 3:
      return "Run or specify a baseline/control sweep and save outputs with indexed filenames under \(labPath)/simulation/outputs/."
    case 4:
      return "Run or design stress cases: disorder, loss, seed sensitivity, resolution, time step, convergence, and boundary perturbations. Update \(labPath)/simulation/STRESS_MATRIX.md."
    case 5:
      return "Audit plots and visualizations for stale data, wrong axes, black frames, misleading normalization, and evidence grade. Write \(labPath)/simulation/PLOT_AUDIT.md."
    case 6:
      return "Optimize reproducibility and performance without changing the science. Create \(labPath)/simulation/REPRODUCIBILITY_NOTES.md."
    case 7:
      return "Compare simulation outcomes to analytic expectations and failure modes. Write \(labPath)/simulation/ANALYTIC_COMPARISON.md."
    case 8:
      return "Package evidence-grade figures/tables and update \(labPath)/ARTIFACT_INDEX.md with every generated output."
    default:
      return "Decide what the simulation proves, what it does not prove, and the next decisive sweep in \(labPath)/simulation/SIMULATION_DECISION.md."
    }
  }

  private func semiconductorMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Choose the model level: k.p, tight-binding, continuum moire, exciton, device, or DFT bridge. Write \(labPath)/semiconductor/MODEL_HIERARCHY.md."
    case 2:
      return "Define symmetry, valley, spin-orbit, strain, dielectric, and optical selection-rule assumptions in \(labPath)/semiconductor/SYMMETRY_AND_ASSUMPTIONS.md."
    case 3:
      return "Derive or specify the key Hamiltonian/observable and limiting regimes. Save \(labPath)/semiconductor/CORE_MODEL.md."
    case 4:
      return "Map Berry curvature/topology/exciton/device observables to measurable predictions in \(labPath)/semiconductor/OBSERVABLES.md."
    case 5:
      return "Attack material specificity: substrate, disorder, twist/moire, screening, temperature, contacts, and sample variability. Write \(labPath)/semiconductor/FAILURE_MODES.md."
    case 6:
      return "Design a calculation or data check that distinguishes competing mechanisms. Create \(labPath)/semiconductor/DECISIVE_TEST.md."
    case 7:
      return "Bridge to DFT or experiment with exact inputs, references, or missing data requirements in \(labPath)/semiconductor/VALIDATION_BRIDGE.md."
    case 8:
      return "Prepare figure/report structure for the semiconductor story in \(labPath)/semiconductor/FIGURE_AND_REPORT_PLAN.md."
    default:
      return "State the strongest material claim and exact next validation path in \(labPath)/semiconductor/SEMICONDUCTOR_DECISION.md."
    }
  }

  private func dftMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Audit existing structures, inputs, outputs, pseudopotentials, XC functional, spin/SOC, vacuum, dipole correction, and prior commands in \(labPath)/dft/DFT_DOSSIER.md."
    case 2:
      return "Design convergence tests for cutoff, k mesh, smearing, relaxation thresholds, and supercell/vacuum in \(labPath)/dft/CONVERGENCE_PLAN.md."
    case 3:
      return "Inspect available outputs or create input templates. Never claim a run happened unless output files exist. Save \(labPath)/dft/INPUT_OUTPUT_AUDIT.md."
    case 4:
      return "Define post-processing for band, DOS, charge, work function, Berry quantities, phonons, or optical observables in \(labPath)/dft/POSTPROCESSING_PLAN.md."
    case 5:
      return "Attack physical validity: finite-size effects, pseudopotential choice, magnetism, SOC, functional dependence, charge state, and structural metastability. Write \(labPath)/dft/DFT_REFEREE_GATE.md."
    case 6:
      return "Create a reproducible run sheet or exact blocker list with commands, expected output files, and runtime constraints in \(labPath)/dft/RUN_SHEET.md."
    case 7:
      return "Plan validation against simpler models, experiment, or literature values. Save \(labPath)/dft/VALIDATION_MATRIX.md."
    case 8:
      return "Build report-ready tables/figures and uncertainty notes in \(labPath)/dft/REPORT_ASSETS.md."
    default:
      return "Decide what the DFT workflow can honestly claim today and the next run queue in \(labPath)/dft/DFT_DECISION.md."
    }
  }

  private func appDevelopmentMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Map the real user workflow, pain points, state invariants, latency targets, and acceptance criteria in \(labPath)/app/WORKFLOW_DOSSIER.md."
    case 2:
      return "Trace architecture and ownership: UI state, queue model, session identity, file transfer, save path, preview cache, and remote helper contracts. Write \(labPath)/app/ARCHITECTURE_MAP.md."
    case 3:
      return "Make a small high-value patch or write the exact blocker. Prefer responsiveness, state correctness, or file/session reliability over cosmetic work. Record \(labPath)/app/PATCH_LOG.md."
    case 4:
      return "Verify with build/static checks and, when possible, installed-app runtime behavior. Save commands/results in \(labPath)/app/VERIFICATION_LOG.md."
    case 5:
      return "Act as a hostile QA reviewer. Look for stale previews, duplicate sessions, stuck queues, broken Normal Send/Steer, attachment loss, and update fragility. Write \(labPath)/app/QA_REFEREE.md."
    case 6:
      return "Repair the highest-risk issue found by QA and update the release checklist in \(labPath)/app/REPAIR_AND_RELEASE_NOTES.md."
    case 7:
      return "Stress persistence and offline/remote behavior: app restart, network drop, queued A worker state, Codex history sync, and file save latency. Write \(labPath)/app/PERSISTENCE_STRESS.md."
    case 8:
      return "Polish the workstation UX: compact controls, readable transcript, predictable panels, and screenshot-level visual QA. Create \(labPath)/app/UX_POLISH.md."
    default:
      return "Ship decision. Summarize exact changes, verification, remaining risk, and next engineering prompts in \(labPath)/app/ENGINEERING_DECISION.md."
    }
  }

  private func designMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Build a design audit from real screenshots, rendered artifacts, or UI inspection, not from memory. Map the user's core workflow, visual hierarchy, density, contrast, affordances, and repeated-use friction. Save \(labPath)/design/DESIGN_DOSSIER.md with screenshot/file evidence and a severity-ranked pain list."
    case 2:
      return "Define the interaction model and component invariants: what is primary, what is secondary, what must stay fixed during resizing, what opens as an overlay, and what must never steal focus. Save \(labPath)/design/INTERACTION_MODEL.md plus a component responsibility table."
    case 3:
      return "Run a visual systems audit: typography scale, line length, spacing rhythm, contrast, hit targets, scroll containment, resize behavior, empty/loading/error states, and click feedback latency. Write \(labPath)/design/UI_AUDIT.md with concrete before/after acceptance checks."
    case 4:
      return "Implement or precisely specify the highest-leverage visual/interaction improvement. Prefer one polished workflow over broad cosmetic churn. Record exact files, tokens/components, and acceptance criteria in \(labPath)/design/CHANGE_SPEC.md."
    case 5:
      return "Run a harsh independent design review. Attack what still feels slow, cramped, ambiguous, visually noisy, or untrustworthy. Include failure states: long Korean text, many queue items, stale file chips, narrow width, bright/dark mode, and remote latency. Write \(labPath)/design/DESIGN_REFEREE.md."
    case 6:
      return "Repair the most important design issue from the referee pass and verify text fit, contrast, scroll containment, and no layout shift. Save \(labPath)/design/REPAIR_LOG.md with commands/screenshots or a precise blocker."
    case 7:
      return "Stress the design across dense data, long prompts, multiple attached files, narrow widths, repeated open/close interactions, and active Codex output. Write \(labPath)/design/STRESS_STATES.md and classify each state PASS, NEEDS_PATCH, or BLOCKED."
    case 8:
      return "Create reusable design-system decisions: token values, control sizes, queue/chip rules, overlay rules, transcript typography, and motion limits. Write \(labPath)/design/DESIGN_SYSTEM.md and update components when safe."
    default:
      return "Make the design director decision. State what is now calmer/faster/clearer, what evidence proves it, what remains visually risky, and the next high-value polish tasks. Save \(labPath)/design/DESIGN_DECISION.md and \(labPath)/design/NEXT_DESIGN_PROMPTS.md."
    }
  }

  private func reportMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Build a report dossier: claim, evidence, figures, tables, methods, limitations, citations, and audience. Save \(labPath)/report/REPORT_DOSSIER.md."
    case 2:
      return "Rewrite the narrative spine: title, abstract thesis, section order, and what each figure must prove. Write \(labPath)/report/NARRATIVE_SPINE.md."
    case 3:
      return "Audit figures/tables/PDFs/images directly where possible. Mark stale, illustrative, invalid, or evidence-grade in \(labPath)/report/FIGURE_TABLE_AUDIT.csv."
    case 4:
      return "Strengthen methods and reproducibility: exact commands, data provenance, parameters, and uncertainty. Write \(labPath)/report/METHODS_REPRODUCIBILITY.md."
    case 5:
      return "Act as a reviewer. Identify overclaims, missing citations, unclear terminology, duplicated prose, weak transitions, and bilingual drift. Write \(labPath)/report/REVIEWER_RISKS.md."
    case 6:
      return "Apply or specify the highest-value prose/figure/report revision. Record before/after in \(labPath)/report/REVISION_LOG.md."
    case 7:
      return "Prepare English/Korean or audience-specific polish only after claims are stable. Save \(labPath)/report/BILINGUAL_OR_AUDIENCE_POLISH.md."
    case 8:
      return "Build final artifact commands and checklist: PDF, figures, citations, privacy, file paths. Write \(labPath)/report/FINAL_ARTIFACT_PLAN.md."
    default:
      return "Make the report decision: publishable, needs major work, or blocked. Save \(labPath)/report/REPORT_DECISION.md and exact next report prompts."
    }
  }

  private func literatureMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Define the review scope, central claims, search keywords, and canonical subfields in \(labPath)/literature/REVIEW_SCOPE.md."
    case 2:
      return "Build a source taxonomy: canonical background, direct competitors, methods controls, and speculative inspiration in \(labPath)/literature/SOURCE_TAXONOMY.md."
    case 3:
      return "Map each source or missing source to claims it supports, weakens, or changes. Save \(labPath)/literature/NOVELTY_MATRIX.md."
    case 4:
      return "Use plugins/search only if available and decision-changing; otherwise write exact searches and local-evidence limits in \(labPath)/literature/SEARCH_LOG.md."
    case 5:
      return "Attack novelty and citation risk. Identify renamed known ideas, missing standard controls, and overbroad claims in \(labPath)/literature/CITATION_RISKS.md."
    case 6:
      return "Revise the research direction based on prior art. Write \(labPath)/literature/DIRECTION_UPDATE.md."
    case 7:
      return "Prepare annotated bibliography entries with claim impact and confidence labels in \(labPath)/literature/ANNOTATED_BIBLIOGRAPHY.md."
    case 8:
      return "Translate literature findings into report/manuscript edits or experiments in \(labPath)/literature/MANUSCRIPT_AND_TEST_IMPACT.md."
    default:
      return "Decide novelty status and next reading queue in \(labPath)/literature/LITERATURE_DECISION.md."
    }
  }

  private func theoryMandate(slot: Int, labPath: String) -> String {
    switch slot {
    case 1:
      return "Name candidate mechanisms and define the core objects, assumptions, and observables in \(labPath)/theory/THEORY_DOSSIER.md."
    case 2:
      return "Formalize the strongest mechanism into equations, invariants, or state transitions. Save \(labPath)/theory/FORMAL_MODEL.md."
    case 3:
      return "Derive predictions and limiting cases. Write \(labPath)/theory/PREDICTIONS.md."
    case 4:
      return "Generate counterexamples and null theories that could explain the same evidence. Save \(labPath)/theory/COUNTER_THEORIES.md."
    case 5:
      return "Run a novelty and naming audit: new theory, recombination, renamed known result, or speculative metaphor. Write \(labPath)/theory/NOVELTY_AUDIT.md."
    case 6:
      return "Repair or kill theories based on counterexamples. Update \(labPath)/theory/KILLED_AND_PROMOTED_THEORIES.md."
    case 7:
      return "Connect the surviving theory to an experiment, simulation, design, or report section. Save \(labPath)/theory/VALIDATION_PATH.md."
    case 8:
      return "Prepare a concise theory note with definitions, theorem-like claims, limitations, and figures in \(labPath)/theory/THEORY_NOTE.md."
    default:
      return "Make the PI theory decision and next theory-building queue in \(labPath)/theory/THEORY_DECISION.md."
    }
  }

  func queueRoleLabel(index: Int, total: Int) -> String {
    let labels: [String]
    switch id {
    case "nature-referee-board":
      switch total {
      case 1:
        labels = ["compressed-referee-board"]
      case 3:
        labels = ["editor-dossier", "sealed-referees", "meta-review-decision"]
      case 6:
        labels = [
          "editor-dossier",
          "referee-theory",
          "referee-methods",
          "referee-novelty",
          "reproducibility-editor",
          "meta-review-decision",
        ]
      default:
        labels = [
          "editor-dossier",
          "referee-theory",
          "referee-methods",
          "referee-novelty",
          "reproducibility-editor",
          "meta-review-decision",
          "author-revision",
          "second-round-review",
          "final-editorial-gate",
        ]
      }
    case "peer-review-lab":
      switch total {
      case 1:
        labels = ["expert-review-sprint"]
      case 3:
        labels = ["review-dossier", "independent-referees", "revision-decision"]
      case 6:
        labels = [
          "review-dossier",
          "harsh-referee",
          "artifact-audit",
          "revision-plan",
          "apply-revisions",
          "verification-gate",
        ]
      default:
        labels = [
          "review-dossier",
          "harsh-referee",
          "artifact-audit",
          "revision-plan",
          "apply-revisions",
          "verification-gate",
          "second-referee",
          "editor-decision",
          "next-review-queue",
        ]
      }
    case "deep-physics":
      labels = roleLabels(
        total: total,
        one: ["physics-professor-sprint"],
        three: ["physics-dossier", "topology-chaos-evidence", "physics-decision"],
        six: [
          "physics-dossier", "minimal-dynamics", "topology-gauge",
          "chaos-control-risk", "robustness-repair", "physics-decision",
        ],
        nine: [
          "physics-dossier", "minimal-dynamics", "topology-gauge",
          "qc-bridge", "chaos-control-risk", "robustness-campaign",
          "numerical-stress", "manuscript-physics", "physics-decision",
        ]
      )
    case "physics-calculation":
      labels = roleLabels(
        total: total,
        one: ["calculation-sprint"],
        three: ["setup-derivation", "audit-numeric-check", "formula-decision"],
        six: [
          "problem-setup", "core-derivation", "consistency-audit",
          "counterexamples", "numerical-check", "formula-decision",
        ],
        nine: [
          "problem-setup", "core-derivation", "consistency-audit",
          "scaling-laws", "counterexamples", "numerical-check",
          "robustness-table", "report-equations", "formula-decision",
        ]
      )
    case "theory-creation":
      labels = roleLabels(
        total: total,
        one: ["theory-sprint"],
        three: ["theory-dossier", "counter-theory-repair", "theory-decision"],
        six: [
          "theory-dossier", "formal-model", "predictions",
          "counter-theories", "novelty-audit", "theory-decision",
        ],
        nine: [
          "theory-dossier", "formal-model", "predictions",
          "counter-theories", "novelty-audit", "kill-or-repair",
          "validation-path", "theory-note", "theory-decision",
        ]
      )
    case "simulation-research":
      labels = roleLabels(
        total: total,
        one: ["simulation-sprint"],
        three: ["simulation-design", "baseline-stress", "simulation-decision"],
        six: [
          "simulation-design", "run-manifest", "baseline-sweep",
          "stress-matrix", "plot-audit", "simulation-decision",
        ],
        nine: [
          "simulation-design", "run-manifest", "baseline-sweep",
          "stress-matrix", "plot-audit", "reproducibility",
          "analytic-comparison", "evidence-package", "simulation-decision",
        ]
      )
    case "two-dimensional-semiconductor":
      labels = roleLabels(
        total: total,
        one: ["semiconductor-sprint"],
        three: ["model-hierarchy", "observable-validation", "semiconductor-decision"],
        six: [
          "model-hierarchy", "symmetry-assumptions", "core-model",
          "observable-map", "failure-modes", "semiconductor-decision",
        ],
        nine: [
          "model-hierarchy", "symmetry-assumptions", "core-model",
          "observable-map", "failure-modes", "decisive-test",
          "validation-bridge", "figure-report-plan", "semiconductor-decision",
        ]
      )
    case "dft-research":
      labels = roleLabels(
        total: total,
        one: ["dft-sprint"],
        three: ["dft-dossier", "convergence-io-audit", "dft-decision"],
        six: [
          "dft-dossier", "convergence-plan", "io-audit",
          "postprocess-plan", "dft-referee", "dft-decision",
        ],
        nine: [
          "dft-dossier", "convergence-plan", "io-audit",
          "postprocess-plan", "dft-referee", "run-sheet",
          "validation-matrix", "report-assets", "dft-decision",
        ]
      )
    case "app-development":
      labels = roleLabels(
        total: total,
        one: ["engineering-sprint"],
        three: ["workflow-architecture", "patch-verify", "ship-decision"],
        six: [
          "workflow-dossier", "architecture-map", "patch",
          "verification", "qa-referee", "ship-decision",
        ],
        nine: [
          "workflow-dossier", "architecture-map", "patch",
          "verification", "qa-referee", "repair-release",
          "persistence-stress", "ux-polish", "ship-decision",
        ]
      )
    case "design-research":
      labels = roleLabels(
        total: total,
        one: ["design-sprint"],
        three: ["design-dossier", "interaction-critique", "design-decision"],
        six: [
          "design-dossier", "interaction-model", "ui-audit",
          "change-spec", "design-referee", "design-decision",
        ],
        nine: [
          "design-dossier", "interaction-model", "ui-audit",
          "change-spec", "design-referee", "repair-log",
          "stress-states", "design-system", "design-decision",
        ]
      )
    case "research-report":
      labels = roleLabels(
        total: total,
        one: ["report-sprint"],
        three: ["report-dossier", "figures-methods-review", "report-decision"],
        six: [
          "report-dossier", "narrative-spine", "figure-audit",
          "methods-repro", "reviewer-risks", "report-decision",
        ],
        nine: [
          "report-dossier", "narrative-spine", "figure-audit",
          "methods-repro", "reviewer-risks", "revision-log",
          "bilingual-polish", "final-artifact-plan", "report-decision",
        ]
      )
    case "literature-review":
      labels = roleLabels(
        total: total,
        one: ["literature-sprint"],
        three: ["review-scope", "novelty-risk", "literature-decision"],
        six: [
          "review-scope", "source-taxonomy", "novelty-matrix",
          "search-log", "citation-risks", "literature-decision",
        ],
        nine: [
          "review-scope", "source-taxonomy", "novelty-matrix",
          "search-log", "citation-risks", "direction-update",
          "annotated-bib", "manuscript-impact", "literature-decision",
        ]
      )
    default:
      switch total {
      case 1:
        labels = ["expert-sprint"]
      case 3:
        labels = ["dossier-and-roles", "evidence-lanes", "professor-synthesis"]
      case 6:
        labels = [
          "program-charter",
          "minimal-model",
          "evidence-campaign",
          "sealed-referee",
          "repair-synthesis",
          "professor-gate",
        ]
      default:
        labels = [
          "orchestrator-dossier",
          "theory-pi",
          "evidence-lead",
          "literature-tools",
          "sealed-referee",
          "contradiction-synthesis",
          "replication-robustness",
          "artifact-upgrade",
          "professor-decision",
        ]
      }
    }
    if index < labels.count {
      return labels[index]
    }
    return id == "nature-referee-board"
      ? "extra-referee-\(index + 1)-of-\(total)"
      : "professor-stage-\(index + 1)-of-\(total)"
  }

  private func roleLabels(
    total: Int,
    one: [String],
    three: [String],
    six: [String],
    nine: [String]
  ) -> [String] {
    switch total {
    case 1: return one
    case 3: return three
    case 6: return six
    default: return nine
    }
  }

  static func clampedLoopCount(_ value: Int) -> Int {
    let clamped = min(max(value, loopCountChoices.first ?? 1), maxLoopCount)
    return loopCountChoices.min {
      abs($0 - clamped) < abs($1 - clamped)
    } ?? defaultLoopCount
  }

  private static func programOperatingSystem(labPath: String, presetTitle: String) -> String {
    """
      Build and maintain a durable research program for \(presetTitle), not just a transcript.
      Required persistent files:
      - \(labPath)/PROGRAM.md: mission, central question, current thesis, operating rules, and today's agenda.
      - \(labPath)/FRONTIER_MAP.md: known territory, unknown territory, risky bridges, and the highest-value frontier.
      - \(labPath)/CLAIM_LEDGER.csv: claim_id, claim, status, evidence, counterevidence, owner_role, next_test.
      - \(labPath)/EVIDENCE_MATRIX.md: analytic evidence vs computational evidence vs literature/tool evidence.
      - \(labPath)/OPEN_PROBLEMS.md: ranked open problems with why they matter and what would close them.
      - \(labPath)/READING_QUEUE.md: papers/docs/tools to inspect, with what each source could change.
      - \(labPath)/COMPUTE_CAMPAIGN.md: planned simulations/calculations, parameters, controls, and success criteria.
      - \(labPath)/REFEREE_GATE.md: skeptical review checklist and claims currently blocked from RESULT status.
      - \(labPath)/MANUSCRIPT_BACKLOG.md: paper/report sections, figures, tables, and narrative gaps.
      - \(labPath)/THEORY_INCUBATOR.md: named new hypotheses, mechanisms, design principles, or killed theory attempts.
      - \(labPath)/REPORT_BACKLOG.md: report/paper sections, required figures, bilingual notes when useful, and reviewer questions.
      - \(labPath)/PLUGIN_AUDIT.md: plugins/tools considered, what they changed, and what was not trusted blindly.
      - \(labPath)/ARTIFACT_INDEX.md: every important file, script, figure, table, report, or generated output with one-line purpose.
      - \(labPath)/DECISION_LOG.md: dated decisions, killed ideas, promoted ideas, blockers, and next owner.

      Quality gates:
      - A claim cannot become RESULT without a named observable, a reproducible check or derivation, and a failure test.
      - A figure cannot be considered decisive unless it has baseline, null/control, stress case, and interpretation.
      - A literature/plugin note cannot replace reasoning; it only changes priors unless connected to equations or data.
      - Every stage must either increase evidence, reduce uncertainty, kill a weak direction, or improve the manuscript/readability.
      - If the run lasts all day, keep the program compact by updating ledgers instead of creating unindexed loose notes.
      - For app/design/report domains, the same evidence discipline applies: inspect real UI/artifacts, define acceptance criteria, run verification, and keep reviewer-ready notes.
      """
  }

  private var domainProtocol: String {
    switch id {
    case "general-research":
      return """
        - First classify the workspace: physics, app, design, report, data, or mixed.
        - Choose one central objective and two backup objectives; avoid scattering effort across unrelated tasks.
        - Build a small evidence loop immediately: inspect files, state claims, test one claim, then update the ledger.
        - Use only plugins that change the decision, not plugins for decoration.
        """
    case "theory-creation":
      return """
        - Generate candidate mechanisms with names, assumptions, mathematical objects, predictions, and failure modes.
        - Attack novelty: decide whether each idea is genuinely new, a recombination, or a renamed known result.
        - Demand at least one formal statement, theorem-like conjecture, counterexample, or derivation fragment.
        - Kill weak theories explicitly so later stages do not keep recycling them.
        """
    case "deep-physics":
      return """
        - Identify the core Hamiltonian, Lagrangian, dynamical matrix, or evolution operator before prose synthesis.
        - Track symmetries, topology, geometric phase, dynamical phase, observables, and gauge/basis choices separately.
        - Search for robustness and failure: disorder, loss, nonadiabaticity, finite size, control noise, and chaos in the mechanical/dynamical implementation itself.
        - Connect any quantum-computing analogy to a measurable gate, channel, phase, fidelity, or readout protocol.
        """
    case "physics-calculation":
      return """
        - Start from equations and units; define state variables, approximations, scales, and boundary conditions.
        - Derive limiting cases before interpreting the full model.
        - Cross-check signs, phases, dimensions, and conservation laws.
        - When possible, pair the analytic result with a minimal numerical sanity check.
        """
    case "simulation-research":
      return """
        - Define observables, parameter ranges, seeds, convergence criteria, and null controls before running simulations.
        - Save outputs in indexed artifacts rather than relying on transcript text.
        - Treat performance, numerical stability, and visualization validity as part of the result.
        - Separate exploratory plots from evidence-grade figures.
        """
    case "two-dimensional-semiconductor":
      return """
        - Choose the model level explicitly: toy Hamiltonian, k.p, tight-binding, continuum moire, exciton, device, or DFT bridge.
        - Track valley, spin-orbit coupling, symmetry, Berry curvature, dielectric screening, strain, and optical/device observables.
        - Separate measurable predictions from material-specific assumptions.
        - Build a path from simplified model to experiment or first-principles validation.
        """
    case "dft-research":
      return """
        - Audit structure, pseudopotential, exchange-correlation choice, cutoff, k-mesh, smearing, spin/SOC, vacuum, dipole correction, and convergence.
        - Never claim a DFT result was run unless outputs exist and commands were executed.
        - Build convergence and reproducibility tables before interpreting bands, DOS, charge, work function, or Berry quantities.
        - Record exact input templates, blockers, and post-processing commands.
        """
    case "app-development":
      return """
        - Start from the real user workflow and define acceptance criteria: latency, state correctness, visual clarity, persistence, errors, and installed-app behavior.
        - Prefer small, verifiable patches over broad rewrites unless the architecture is the blocker.
        - Validate with build, static checks, privacy scan, installed-app launch, and screenshot/runtime inspection when UI changes.
        - Keep Send/Steer, queue state, preview freshness, and background work semantics explicit.
        """
    case "design-research":
      return """
        - Inspect the real UI or screenshot before judging. Do not design from imagination when evidence is available.
        - Evaluate hierarchy, spacing, density, contrast, resize behavior, empty/loading states, affordances, and repeated-use ergonomics.
        - Prefer quiet workstation-grade polish over decorative flourishes.
        - Convert critique into concrete component/token/layout changes and verify text fit.
        """
    case "research-report":
      return """
        - Separate paper narrative from raw notes: claim, evidence, figure, method, limitation, citation.
        - Make figures and tables earn their place; verify generated artifacts before citing them.
        - Produce reviewer-ready English and Korean structure when useful, but do not let translation hide weak claims.
        - Maintain an abstract, outline, figure roadmap, claim-evidence matrix, and final risk checklist.
        """
    case "literature-review":
      return """
        - Build a novelty matrix, not a bibliography dump.
        - For each source, record what claim it supports, weakens, or changes.
        - Distinguish canonical background, direct competitors, missing controls, and speculative inspiration.
        - If browsing/plugins are unavailable, write the exact search plan and continue with local evidence.
        """
    default:
      return """
        - Use the preset domain brief as the operating contract.
        - Create artifacts, test claims, update ledgers, and leave exact next actions.
        """
    }
  }

  private func peerReviewLabPrompts(
    sessionName: String,
    sessionDir: String,
    pluginContext: String,
    researchRequest: String,
    requestedLoopCount: Int,
    labPath: String,
    programOS: String
  ) -> [String] {
    let total = requestedLoopCount
    let reviewPath = "\(labPath)/peer_review"
    let common = """
      Peer Review Lab preset: \(title)
      Active session: \(sessionName)
      Working directory: \(sessionDir)
      Durable review path: \(reviewPath)

      User review request:
      \(researchRequest)

      Purpose:
      Review the active work like a serious external referee, then turn the review into exact revision work. Do not reward fluency. Reward evidence, reproducibility, precision, and corrected artifacts.

      Review standard:
      - Read the recent transcript, generated reports, figures, scripts, data tables, PDFs/images, and artifact indexes before judging.
      - Separate author claims from actual evidence.
      - Mark every important claim RESULT, CONJECTURE, FAILURE, or NOT_CHECKED.
      - Look for stale previews, black or invalid figures, duplicated headings, unsupported report wording, gauge/basis mistakes, weak controls, missing uncertainty, and claims that outrun the evidence.
      - If a relevant plugin is available, use it where it materially improves the review; record what it changed.
      - Keep transcript output short. Put detailed review material into files under \(reviewPath)/.

      Handoff rules:
      - Every stage must read \(reviewPath)/HANDOFF.md if it exists.
      - Every stage must update \(reviewPath)/HANDOFF.md before ending.
      - The next stage should continue from the strongest unresolved blocker, not repeat the same critique.

      Research Program OS:
      \(programOS)

      Available plugin/tool context:
      \(pluginContext)
      """

    if total == 1 {
      return [
        """
        \(common)

        Stage 1/1: expert peer-review sprint.
        Run the full review in one serious pass. Build the dossier, write two independent short referee notes, audit at least one decisive artifact or command, then produce the editor decision and revision queue. Do not stop at a plan.

        Deliver:
        - \(reviewPath)/DOSSIER.md
        - \(reviewPath)/sealed/referee_a/REPORT.md
        - \(reviewPath)/sealed/referee_b/REPORT.md
        - \(reviewPath)/ARTIFACT_AUDIT.md
        - \(reviewPath)/EDITOR_DECISION.md
        - \(reviewPath)/MANDATORY_REVISIONS.md
        - \(reviewPath)/CLAIM_LEDGER.csv
        - \(reviewPath)/HANDOFF.md
        """
      ]
    }

    if total == 3 {
      return [
        """
        \(common)

        Stage 1/3: review dossier and independence setup.
        Build a neutral dossier and sealed review protocol. Extract claims, artifacts, missing evidence, and the exact files to inspect.

        Deliver:
        - \(reviewPath)/DOSSIER.md
        - \(reviewPath)/CLAIM_LEDGER.csv
        - \(reviewPath)/ARTIFACT_AUDIT.md
        - \(reviewPath)/HANDOFF.md
        """,
        """
        \(common)

        Stage 2/3: independent referee board and artifact audit.
        Write at least two separated referee reports before synthesis: one theory/claim referee and one artifact/reproducibility referee. If subagents are available, spawn them with sealed paths. Verify or directly inspect the most important artifact when feasible.

        Deliver:
        - \(reviewPath)/sealed/referee_claims/REPORT.md
        - \(reviewPath)/sealed/referee_artifacts/REPORT.md
        - \(reviewPath)/FIGURE_TABLE_AUDIT.csv or exact blocker.
        - \(reviewPath)/HANDOFF.md
        """,
        """
        \(common)

        Stage 3/3: editor decision and revision work.
        Read the sealed reports, resolve contradictions, apply one high-value safe revision if possible, and produce the final decision. Do not paste reports side by side.

        Deliver:
        - \(reviewPath)/EDITOR_DECISION.md
        - \(reviewPath)/MANDATORY_REVISIONS.md
        - \(reviewPath)/APPLIED_REVISIONS.md or \(reviewPath)/REVISION_BLOCKER.md
        - \(reviewPath)/NEXT_REVIEW_QUEUE.md
        - \(reviewPath)/ARTIFACT_INDEX.md
        """
      ]
    }

    let prompts = [
      """
      \(common)

      Stage 1/\(total): review dossier.
      Build the neutral dossier before making recommendations.

      Deliver:
      - \(reviewPath)/DOSSIER.md with transcript scope, artifacts inspected, files missing, and central claims.
      - \(reviewPath)/CLAIM_LEDGER.csv with claim_id, claim, evidence, status, needed_test.
      - \(reviewPath)/ARTIFACT_AUDIT.md with every important report/figure/script and whether it is valid, stale, black, missing, or illustrative only.
      - \(reviewPath)/HANDOFF.md with the top three risks for the next stage.
      """,
      """
      \(common)

      Stage 2/\(total): harsh referee report.
      Read \(reviewPath)/DOSSIER.md and \(reviewPath)/HANDOFF.md. Write as a skeptical but constructive referee.

      Deliver:
      - \(reviewPath)/REFEREE_REPORT.md with major issues, minor issues, decision recommendation, and exact evidence.
      - \(reviewPath)/OVERCLAIMS.md listing claims whose wording must be weakened or backed by new evidence.
      - \(reviewPath)/MANDATORY_REVISIONS.md ranked by scientific or product risk.
      - Updated \(reviewPath)/HANDOFF.md with the one revision that would most improve credibility.
      """,
      """
      \(common)

      Stage 3/\(total): artifact and reproducibility audit.
      Read previous review files. Verify the most important artifacts directly where possible.

      Deliver:
      - \(reviewPath)/REPRODUCIBILITY_AUDIT.md with exact commands attempted or required.
      - \(reviewPath)/FIGURE_TABLE_AUDIT.csv with valid/stale/missing/invalid labels.
      - A small verification script, regenerated figure/table, or exact blocker if feasible.
      - Updated \(reviewPath)/HANDOFF.md with reproducibility blockers and next commands.
      """,
      """
      \(common)

      Stage 4/\(total): revision plan and claim triage.
      Convert the review into an executable plan. Do not just summarize the critique.

      Deliver:
      - \(reviewPath)/REVISION_PLAN.md with ordered tasks, owner, target files, expected verification, and failure criteria.
      - \(reviewPath)/CLAIM_STATUS_AFTER_REVIEW.csv with RESULT/CONJECTURE/FAILURE/NOT_CHECKED.
      - \(reviewPath)/NEXT_COMMANDS.md with exact prompts or shell commands for revision.
      - Updated \(reviewPath)/HANDOFF.md naming the first revision to implement.
      """,
      """
      \(common)

      Stage 5/\(total): apply the highest-value revisions.
      Read \(reviewPath)/REVISION_PLAN.md. Apply the top safe revisions directly if they are in scope. If a revision is too large, create a precise patch plan and do one smaller high-confidence fix.

      Deliver:
      - Changed project files or \(reviewPath)/REVISION_BLOCKER.md.
      - \(reviewPath)/APPLIED_REVISIONS.md with file paths, reason, and before/after claim status.
      - Updated artifact index and verification commands.
      - Updated \(reviewPath)/HANDOFF.md for second review.
      """,
      """
      \(common)

      Stage 6/\(total): second-pass referee gate.
      Re-read the changed files and review outputs. Act as a different reviewer who is not emotionally attached to the revision.

      Deliver:
      - \(reviewPath)/SECOND_PASS_REVIEW.md with what improved, what still fails, and whether claims can be upgraded.
      - \(reviewPath)/REMAINING_BLOCKERS.md.
      - Verification output or exact commands.
      - Updated \(reviewPath)/HANDOFF.md for final editor decision.
      """,
      """
      \(common)

      Stage 7/\(total): editor decision and next research queue.
      Produce a final decision letter and the next high-value research queue.

      Deliver:
      - \(reviewPath)/EDITOR_DECISION.md with decision, mandatory remaining revisions, and acceptance criteria.
      - \(reviewPath)/NEXT_REVIEW_QUEUE.md with 3 concrete follow-up prompts, each tied to exact files and failure criteria.
      - \(reviewPath)/ARTIFACT_INDEX.md updated.
      - A concise transcript summary with the decision and exact files.
      """,
    ]
    if total <= prompts.count {
      return Array(prompts.prefix(total))
    }
    let extras = (prompts.count + 1...total).map { index in
      """
      \(common)

      Stage \(index)/\(total): second-round review and anti-bias gate.
      Read the editor decision and mandatory revisions. Act as a new reviewer, not the same author. Verify one changed artifact or claim, then decide whether to upgrade, downgrade, or keep the claim status.

      Deliver:
      - \(reviewPath)/round2/\(String(format: "%02d", index))_second_round_gate.md
      - Updated \(reviewPath)/CLAIM_LEDGER.csv when status changed.
      - Exact verification commands or blocker.
      - Updated \(reviewPath)/HANDOFF.md.
      """
    }
    return prompts + extras
  }

  private func natureRefereeBoardPrompts(
    sessionName: String,
    sessionDir: String,
    pluginContext: String,
    researchRequest: String,
    requestedLoopCount: Int,
    labPath: String,
    programOS: String
  ) -> [String] {
    let total = requestedLoopCount
    let boardPath = "\(labPath)/referee_board"
    let common = """
      Nature Referee Board preset: \(title)
      Active session: \(sessionName)
      Working directory: \(sessionDir)
      Durable review board path: \(boardPath)

      User review request:
      \(researchRequest)

      Purpose:
      Build a self-critical peer-review system strong enough to catch errors before a serious journal referee does. Do not protect previous assistant conclusions. Treat all claims as provisional until the evidence survives independent review.

      Independence protocol:
      - This is a sub-session style review board. Each referee writes only inside their own sealed directory first.
      - A referee must read the dossier and raw project artifacts, but must not read other referee reports before finishing their own report.
      - If the runtime exposes subagents/subsessions, spawn independent reviewer agents with disjoint write paths and ask them not to share intermediate conclusions.
      - If subagents are unavailable, emulate independence: clear your prior synthesis from working memory as much as possible, write the referee report before opening any other referee output, and explicitly list possible self-bias.
      - The meta-reviewer may open all sealed reports only after at least two independent referee reports exist.

      Nature-level review standard:
      - Novelty: what is genuinely new versus known, incremental, or merely relabeled.
      - Conceptual advance: whether the central mechanism changes how a field thinks.
      - Evidence: analytic derivation, computation, experimental/simulation artifact, controls, stress tests, uncertainty, and reproducibility.
      - Claims discipline: every important statement must be RESULT, CONJECTURE, or FAILURE.
      - Alternative explanations: null models, gauge/basis conventions, finite-size effects, units, hidden assumptions, plotting artifacts, cherry-picked parameters, and literature conflicts.
      - Editorial decision: Accept, Minor Revision, Major Revision, Reject-but-resubmit, or Reject, with exact conditions for upgrade.

      Available plugin/tool context:
      \(pluginContext)

      Research Program OS:
      \(programOS)

      Output rules:
      - Prefer durable files over transcript-only critique.
      - Update \(boardPath)/ARTIFACT_INDEX.md whenever a review file is created.
      - Do not write vague encouragement. Write precise failure tests and revision commands.
      - Keep visible transcript concise, but make the review files detailed and reusable.
      - Read \(boardPath)/HANDOFF.md if it exists, then update it before ending this stage.
      - Do not repeat prior stages. Each stage must either expose a new risk, verify a claim, revise a file, or sharpen the editor decision.
      """

    if total == 1 {
      return [
        """
        \(common)

        Stage 1/1: compressed Nature referee board.
        Run a compact but real board in one stage. Build the dossier, write at least three separated sealed referee notes (theory, methods/reproducibility, novelty), then open them only for a final meta-review decision. Do not write a single-author opinion disguised as a board.

        Deliver:
        - \(boardPath)/DOSSIER.md
        - \(boardPath)/sealed/referee_theory/REPORT.md
        - \(boardPath)/sealed/referee_methods/REPORT.md
        - \(boardPath)/sealed/referee_novelty/REPORT.md
        - \(boardPath)/META_REVIEW_DECISION.md
        - \(boardPath)/MANDATORY_REVISIONS.md
        - \(boardPath)/CLAIM_STATUS_AFTER_REVIEW.csv
        - \(boardPath)/ARTIFACT_INDEX.md
        """
      ]
    }

    if total == 3 {
      return [
        """
        \(common)

        Stage 1/3: editorial dossier and review protocol.
        Build the neutral dossier and sealed-board rules. Extract central claims, evidence, artifacts, missing checks, and the decision standard.

        Deliver:
        - \(boardPath)/DOSSIER.md
        - \(boardPath)/CLAIMS_UNDER_REVIEW.csv
        - \(boardPath)/ARTIFACT_AUDIT.md
        - \(boardPath)/REVIEW_PROTOCOL.md
        - \(boardPath)/HANDOFF.md
        """,
        """
        \(common)

        Stage 2/3: sealed referee reports.
        Produce independent sealed reports for theory/novelty and methods/reproducibility. If subagents are available, spawn them with sealed directories. The reports must not read each other before they are complete.

        Deliver:
        - \(boardPath)/sealed/referee_theory_novelty/REPORT.md
        - \(boardPath)/sealed/referee_methods_reproducibility/REPORT.md
        - \(boardPath)/sealed/referee_theory_novelty/CLAIM_DECISIONS.csv
        - \(boardPath)/sealed/referee_methods_reproducibility/REPRODUCIBILITY_TABLE.md
        - \(boardPath)/HANDOFF.md
        """,
        """
        \(common)

        Stage 3/3: meta-review, decision, and revision queue.
        Read the sealed reports only now. Resolve contradictions, issue the editorial decision, and write exact mandatory revisions and follow-up prompts.

        Deliver:
        - \(boardPath)/META_REVIEW_DECISION.md
        - \(boardPath)/MANDATORY_REVISIONS.md
        - \(boardPath)/CLAIM_STATUS_AFTER_REVIEW.csv
        - \(boardPath)/NEXT_RESEARCH_COMMANDS.md
        - \(boardPath)/ARTIFACT_INDEX.md
        """
      ]
    }

    let prompts = [
      """
      \(common)

      Stage 1/\(total): editorial dossier builder.
      Create the review dossier that all later referees will use. Do not judge the work yet except to identify the claims and evidence.

      Tasks:
      - Read the recent transcript if available, repository files, generated reports, scripts, CSV/JSON summaries, figures, and artifact indexes.
      - Build a neutral dossier: claim map, artifact map, evidence table, and missing-file/black-artifact list.
      - Extract the strongest central claim and the strongest possible conservative version of that claim.
      - Separate raw evidence from author interpretation.

      Deliver:
      - \(boardPath)/DOSSIER.md
      - \(boardPath)/CLAIMS_UNDER_REVIEW.csv
      - \(boardPath)/ARTIFACT_AUDIT.md
      - \(boardPath)/REVIEW_PROTOCOL.md
      - \(boardPath)/ARTIFACT_INDEX.md
      - \(boardPath)/HANDOFF.md
      """,
      """
      \(common)

      Stage 2/\(total): sealed Referee A - theory and conceptual novelty.
      Work as an independent theory referee. Read \(boardPath)/DOSSIER.md and raw source artifacts only. Do not read any other referee directory.

      Focus:
      - Is the central theory actually new, or only a known Berry/topology idea renamed?
      - Are the Hamiltonian, dynamical matrix, gauge convention, edge subspace, and observables defined cleanly?
      - Does the argument distinguish geometric sign, global phase, logical gate, topological protection, and dynamic phase?
      - What theorem, derivation, or counterexample would change the decision?

      Deliver:
      - \(boardPath)/sealed/referee_theory/REPORT.md
      - \(boardPath)/sealed/referee_theory/CLAIM_DECISIONS.csv
      - \(boardPath)/sealed/referee_theory/REQUIRED_THEORY_REVISIONS.md
      - \(boardPath)/HANDOFF.md updated with theory blockers.
      """,
      """
      \(common)

      Stage 3/\(total): sealed Referee B - methods, numerics, and reproducibility.
      Work as an independent methods referee. Read \(boardPath)/DOSSIER.md, scripts, summaries, and raw outputs. Do not read other referee directories.

      Focus:
      - Re-run or audit the key commands if feasible.
      - Check gauge/basis convention dependence, finite-size effects, parameter cherry-picking, seed counts, confidence intervals, phase wrapping, dynamic-phase subtraction, loss/visibility, and black/stale figure artifacts.
      - Identify the smallest additional test that would most improve credibility.

      Deliver:
      - \(boardPath)/sealed/referee_methods/REPORT.md
      - \(boardPath)/sealed/referee_methods/REPRODUCIBILITY_TABLE.md
      - \(boardPath)/sealed/referee_methods/REQUIRED_METHODS_REVISIONS.md
      - Any small verification script/table/figure you can complete now.
      - \(boardPath)/HANDOFF.md updated with methods blockers.
      """,
      """
      \(common)

      Stage 4/\(total): sealed Referee C - literature, novelty, and scope.
      Work as an independent novelty/literature referee. Read \(boardPath)/DOSSIER.md and project bibliography/source notes. Do not read other referee directories.

      Focus:
      - Compare claims against Berry phase, Hannay angle, SSH/topological mechanics, Floquet synthetic gauge, non-Hermitian topology, and quantum-gate literature.
      - Identify missing citations or prior art that could weaken novelty.
      - Decide what would make this Nature-level broad-interest versus a narrower technical note.
      - If online/literature plugins are available, use them carefully and cite what changed; if not, write the missing search plan.

      Deliver:
      - \(boardPath)/sealed/referee_novelty/REPORT.md
      - \(boardPath)/sealed/referee_novelty/NOVELTY_MATRIX.md
      - \(boardPath)/sealed/referee_novelty/CITATION_RISKS.md
      - \(boardPath)/HANDOFF.md updated with novelty blockers.
      """,
      """
      \(common)

      Stage 5/\(total): reproducibility and data/code editor.
      Work as a specialist editor, still independent from the final meta-review. You may read the dossier and raw artifacts; read referee reports only if needed to locate issues, and note when you did.

      Focus:
      - Data/code availability, exact commands, generated artifact freshness, figure validity, black screenshots, stale previews, privacy-sensitive files, and whether another researcher can reproduce the core result tomorrow.
      - Mark every figure/table as valid evidence, illustrative only, stale, missing, or invalid.
      - Propose exact file moves/deletions/regenerations.

      Deliver:
      - \(boardPath)/sealed/reproducibility_editor/REPORT.md
      - \(boardPath)/sealed/reproducibility_editor/FIGURE_TABLE_AUDIT.csv
      - \(boardPath)/sealed/reproducibility_editor/REPRODUCTION_COMMANDS.md
      - \(boardPath)/HANDOFF.md updated with reproducibility blockers.
      """,
      """
      \(common)

      Stage 6/\(total): meta-review and editor decision.
      Now, and only now, read all sealed referee reports. Resolve contradictions instead of pasting reports side by side.

      Tasks:
      - Produce a Nature-style decision letter.
      - Decide claim-by-claim: RESULT, CONJECTURE, FAILURE.
      - Produce mandatory revisions, optional revisions, and rejection-level blockers.
      - Convert the decision into exact next prompts/commands for the research agent.
      - Update the active project ledgers if appropriate.

      Deliver:
      - \(boardPath)/META_REVIEW_DECISION.md
      - \(boardPath)/MANDATORY_REVISIONS.md
      - \(boardPath)/CLAIM_STATUS_AFTER_REVIEW.csv
      - \(boardPath)/NEXT_RESEARCH_COMMANDS.md
      - \(boardPath)/HANDOFF.md updated with the next revision gate.
      - A concise transcript summary with the editorial decision and exact files.
      """,
    ]

    if total <= prompts.count {
      return Array(prompts.prefix(total))
    }

    let extras = (prompts.count + 1...total).map { index in
      """
      \(common)

      Stage \(index)/\(total): post-review revision and second-round gate.
      Read \(boardPath)/META_REVIEW_DECISION.md and \(boardPath)/MANDATORY_REVISIONS.md. Apply one high-value mandatory revision, then run a second-round referee gate against the changed artifacts.

      Deliver:
      - \(boardPath)/round2/\(String(format: "%02d", index))_revision_gate.md
      - Updated project files or a precise blocker.
      - Verification commands and results.
      - A decision on whether the revision moved any claim from FAILURE to CONJECTURE, CONJECTURE to RESULT, or RESULT down.
      """
    }
    return prompts + extras
  }
}

struct CodexResearchPresetGroup: Identifiable, Hashable {
  var id: String
  var title: String
  var symbol: String
  var presetIDs: [String]
}

enum CodexResearchPresetLibrary {
  static let all: [CodexResearchPreset] = [
    .init(
      id: "general-research",
      title: "General Research",
      subtitle: "Universal professor lab for any project",
      symbol: "sparkles.rectangle.stack",
      domainBrief:
        "Use the active workspace as a serious research lab regardless of domain. Infer the project type from files, transcript, and artifacts, then build a durable research program with claims, evidence, counterarguments, experiments, and reportable outputs.",
      outputFocus:
        "A reusable research program, artifact index, claim ledger, evidence matrix, and next-action queue that can keep running even after the app disconnects."
    ),
    .init(
      id: "peer-review-lab",
      title: "Peer Review Lab",
      subtitle: "Read transcript/artifacts, referee claims, then revise",
      symbol: "checklist.checked",
      domainBrief:
        "Act first as a hostile but constructive peer reviewer. Read the recent transcript, every cited artifact, generated report, figure, table, script, and validation output before proposing new work. Identify overclaims, missing controls, stale or black screenshots, unsupported figures, duplicated headings, weak statistics, gauge/basis issues, and claims whose wording outruns the evidence. Then switch into revision mode: issue exact fixes, update ledgers, improve reports, run verification, and leave a reviewer-ready decision log.",
      outputFocus:
        "A referee report, mandatory revision list, claim downgrade/upgrade table, artifact audit, exact follow-up commands, corrected reports/figures when appropriate, and a next research queue that starts from the review rather than from generic continuation."
    ),
    .init(
      id: "nature-referee-board",
      title: "Nature Referee Board",
      subtitle: "Sealed multi-referee board and editor decision",
      symbol: "person.3.sequence",
      domainBrief:
        "Run a sub-session style referee board. First build a neutral dossier, then force independent sealed reviewers for theory, methods/numerics, novelty/literature, and reproducibility before a final meta-reviewer reads the reports. Hold the work to a high-impact journal standard: novelty, decisive evidence, controls, uncertainty, reproducibility, alternative explanations, and exact mandatory revisions.",
      outputFocus:
        "Sealed referee reports, figure/data/code audit, claim-status table, Nature-style decision letter, mandatory revision commands, and second-round review gates that reduce self-confirmation bias."
    ),
    .init(
      id: "theory-creation",
      title: "Theory Builder",
      subtitle: "Invent, formalize, attack, and repair new theory",
      symbol: "lightbulb.max",
      domainBrief:
        "Prioritize genuinely new theory formation. Invent named hypotheses or mechanisms, formalize assumptions, derive consequences, seek counterexamples, and keep only ideas that survive analytic, computational, or artifact-based pressure.",
      outputFocus:
        "Theory incubator notes, derivations, falsifiable predictions, counterexamples, and a clean ledger of promoted and killed ideas."
    ),
    .init(
      id: "deep-physics",
      title: "Deep Physics",
      subtitle: "Theory, topology, quantum/classical bridge",
      symbol: "atom",
      domainBrief:
        "Use the active workspace as a physics research lab. Push beyond explanation into analytic structure, topology, gate analogies, Berry/Hannay phases, robustness, and falsifiable calculations. Infer the concrete research context from files and transcripts instead of assuming a fixed project.",
      outputFocus:
        "Research notes, derivations, simulation scripts, figures, and a paper-grade claim map for the active project."
    ),
    .init(
      id: "physics-calculation",
      title: "Physics Calculation",
      subtitle: "Analytic derivation, scaling laws, falsifiable claims",
      symbol: "function",
      domainBrief:
        "Prioritize first-principles reasoning, equations of motion, Hamiltonians/Lagrangians, perturbative limits, symmetry constraints, conserved quantities, and exact or asymptotic checks.",
      outputFocus:
        "Derivation files, validated formulae, sanity checks, and a table of predictions versus assumptions."
    ),
    .init(
      id: "simulation-research",
      title: "Simulation Research",
      subtitle: "Numerical experiments, sweeps, robustness",
      symbol: "waveform.path.ecg",
      domainBrief:
        "Treat the repository as a simulation lab. Build reproducible numerical experiments with baselines, controls, parameter sweeps, disorder/noise tests, convergence checks, and visualization.",
      outputFocus:
        "Runnable scripts, CSV/JSON/NPZ outputs, plots, benchmark notes, and a clear artifact index."
    ),
    .init(
      id: "two-dimensional-semiconductor",
      title: "2D Semiconductor",
      subtitle: "Valley, exciton, moire, Berry curvature, devices",
      symbol: "square.grid.3x3",
      domainBrief:
        "Think like a condensed-matter researcher working on 2D semiconductors. Consider band structure, valleys, spin-orbit coupling, excitons, moire potentials, strain, dielectric screening, Berry curvature, optical selection rules, and device observables.",
      outputFocus:
        "A model hierarchy from toy Hamiltonian to measurable predictions, plus scripts/figures where the current workspace supports them."
    ),
    .init(
      id: "dft-research",
      title: "DFT Research",
      subtitle: "Workflow design, inputs, convergence, interpretation",
      symbol: "cube.transparent",
      domainBrief:
        "Think like a computational materials researcher. Inspect available DFT inputs/outputs if present, design convergence tests, k-point/cutoff/smearing checks, structure relaxation strategy, band/DOS/work-function plans, and post-processing.",
      outputFocus:
        "DFT workflow notes, input templates or audit reports, convergence matrices, and a blocker-aware run plan."
    ),
    .init(
      id: "app-development",
      title: "App Development",
      subtitle: "Architecture, UX latency, tests, shipping quality",
      symbol: "hammer",
      domainBrief:
        "Think like a senior product engineer and systems researcher. Improve the app as a working workstation: responsiveness, session correctness, durable queues, file preview correctness, error visibility, tests, privacy, installed-app behavior, and upgrade resilience. Treat UX latency and state correctness as research questions with measurable claims.",
      outputFocus:
        "Scoped patches, verification commands, latency/correctness evidence, before/after notes, release-quality checklist, and a durable engineering decision log."
    ),
    .init(
      id: "design-research",
      title: "Design Research",
      subtitle: "Interaction model, visual polish, product feel",
      symbol: "paintpalette",
      domainBrief:
        "Think like a product designer, design systems researcher, and design engineer. Study workflow friction, information hierarchy, contrast, resizing, affordances, typography, empty/loading states, repeated-use ergonomics, and how the interface changes the user's ability to think and work.",
      outputFocus:
        "Design critique, interaction principles, implemented UI refinements when appropriate, screenshot QA plan, accessibility/contrast notes, and a reusable design-token or component-system note."
    ),
    .init(
      id: "research-report",
      title: "Research Report",
      subtitle: "Paper/report writing, evidence, figures, bilingual polish",
      symbol: "doc.richtext",
      domainBrief:
        "Think like a professor preparing a paper, technical report, or research memo. Build a strong narrative from evidence, separate claims from speculation, improve figures/tables, inspect generated artifacts, and prepare reviewer-ready Korean and English prose when useful.",
      outputFocus:
        "Report outline, abstract, bilingual draft notes, figure roadmap, claim/evidence mapping, reviewer-risk checklist, final artifact index, and exact commands used to produce or verify outputs."
    ),
    .init(
      id: "literature-review",
      title: "Literature Review",
      subtitle: "Papers, prior art, citations, novelty map",
      symbol: "books.vertical",
      domainBrief:
        "Think like a scholar doing a novelty and prior-art review. Use available literature plugins when possible, but never let citations replace reasoning. Connect sources to concrete claims, models, assumptions, and gaps in the active project.",
      outputFocus:
        "Reading queue, annotated bibliography, novelty matrix, citation-risk notes, and concrete changes to the research direction or report."
    )
  ]

  static let groups: [CodexResearchPresetGroup] = [
    .init(
      id: "peer-review",
      title: "Peer Review",
      symbol: "checklist.checked",
      presetIDs: ["peer-review-lab", "nature-referee-board", "research-report", "literature-review"]
    ),
    .init(
      id: "physics-research",
      title: "Physics Research",
      symbol: "atom",
      presetIDs: [
        "deep-physics", "physics-calculation", "simulation-research", "theory-creation",
        "general-research",
        "two-dimensional-semiconductor",
      ]
    ),
    .init(
      id: "dft",
      title: "DFT",
      symbol: "cube.transparent",
      presetIDs: ["dft-research"]
    ),
    .init(
      id: "app-build",
      title: "App Build",
      symbol: "hammer",
      presetIDs: ["app-development"]
    ),
    .init(
      id: "design",
      title: "Design",
      symbol: "paintpalette",
      presetIDs: ["design-research"]
    ),
  ]

  static func presets(in group: CodexResearchPresetGroup) -> [CodexResearchPreset] {
    group.presetIDs.compactMap { id in all.first { $0.id == id } }
  }
}

struct CodexResearchPresetMenu: View {
  @EnvironmentObject private var model: AppModel
  @AppStorage("AControl.researchPresetLoopCount") private var storedLoopCount =
    CodexResearchPreset.defaultLoopCount
  var compact = false
  var selectedPreset: CodexResearchPreset?
  var onSelect: (CodexResearchPreset) -> Void = { _ in }
  var onClear: () -> Void = {}

  private var loopCount: Int {
    CodexResearchPreset.clampedLoopCount(storedLoopCount)
  }

  var body: some View {
    Menu {
      Button {
        onClear()
      } label: {
        Label(
          "Normal Send",
          systemImage: selectedPreset == nil ? "checkmark.circle.fill" : "paperplane"
        )
      }
      Divider()
      Section("Depth") {
        ForEach(CodexResearchPreset.loopCountChoices, id: \.self) { count in
          Button {
            storedLoopCount = count
          } label: {
            Label(
              "\(count) stage\(count == 1 ? "" : "s")",
              systemImage: loopCount == count ? "checkmark.circle.fill" : "circle"
            )
          }
        }
      }
      Divider()
      Section("Professor Lab mode") {
        ForEach(CodexResearchPresetLibrary.groups) { group in
          Menu {
            ForEach(CodexResearchPresetLibrary.presets(in: group)) { preset in
              Button {
                onSelect(preset)
              } label: {
                Label(
                  preset.title,
                  systemImage: selectedPreset?.id == preset.id
                    ? "checkmark.circle.fill" : preset.symbol
                )
              }
              .safeHelp(preset.subtitle)
            }
          } label: {
            Label(
              group.title,
              systemImage: selectedPreset.map { group.presetIDs.contains($0.id) } == true
                ? "checkmark.circle.fill" : group.symbol
            )
          }
        }
      }
      Divider()
      Button {
        Task { await model.checkCodexPlugins() }
      } label: {
        Label("Refresh Installed Plugins", systemImage: "arrow.clockwise")
      }
    } label: {
      if compact {
        Image(systemName: selectedPreset?.symbol ?? "paperplane")
      } else {
        Label(
          selectedPreset.map { "\($0.title) · \(loopCount) stages" } ?? "Normal Send",
          systemImage: selectedPreset?.symbol ?? "paperplane"
        )
      }
    }
    .menuStyle(.button)
    .safeHelp("Normal send, or apply a one-shot Professor Lab workflow to the next prompt")
  }
}
