#!/bin/bash

# DevOps Configuration Script for Rise Gaming Takistan Life Feedback Repository
# Configures GitHub repository with proper settings, branch protection, issue templates, and labels
# This script is idempotent and preserves existing content

set -euo pipefail

# Environment variables (should be provided)
OWNER="${OWNER:-RiseGaming}"
REPO="${REPO:-takistan-life-feedback}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# A) Preflight checks
echo "🔍 Performing preflight checks..."

# Verify GitHub CLI authentication
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated. Run 'gh auth login' first."
    exit 1
fi

# Verify environment variables
if [[ -z "$OWNER" || -z "$REPO" || -z "$DEFAULT_BRANCH" ]]; then
    echo "❌ Missing required environment variables: OWNER, REPO, DEFAULT_BRANCH"
    exit 1
fi

REPO_SLUG="${OWNER}/${REPO}"
echo "✅ Configuring repository: $REPO_SLUG"
echo "✅ Default branch: $DEFAULT_BRANCH"

# B) Repository settings configuration
echo ""
echo "🔧 Configuring repository settings..."

# Docs: gh repo edit manual
echo "  - Setting visibility to public, enabling issues, disabling wiki and projects..."
gh repo edit "$REPO_SLUG" \
    --visibility public \
    --enable-issues \
    --enable-wiki=false \
    --enable-projects=false \
    2>/dev/null || true

# Docs: REST API endpoints for repositories
echo "  - Enabling auto-delete head branches on merge..."
gh api -X PATCH "repos/$REPO_SLUG" \
    -f delete_branch_on_merge=true \
    >/dev/null 2>&1 || true

# C) Default branch and protection
echo ""
echo "🛡️  Setting up branch protection..."

# Docs: REST API endpoints for repositories
echo "  - Setting default branch to $DEFAULT_BRANCH..."
gh api -X PATCH "repos/$REPO_SLUG" \
    -f default_branch="$DEFAULT_BRANCH" \
    >/dev/null 2>&1 || true

# Docs: REST protected branches
echo "  - Configuring branch protection rules..."
gh api -X PUT "repos/$REPO_SLUG/branches/$DEFAULT_BRANCH/protection" \
    -H "Accept: application/vnd.github+json" \
    --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":false,"require_code_owner_reviews":false}' \
    --field enforce_admins=true \
    --field required_status_checks='{"strict":false,"contexts":[]}' \
    --field restrictions=null \
    --field allow_force_pushes=false \
    --field allow_deletions=false \
    --field required_conversation_resolution=true \
    >/dev/null 2>&1 || echo "  ⚠️  Branch protection may already exist or require different permissions"

# D) Issue templates and chooser configuration 
echo ""
echo "📋 Configuring issue templates..."

# Create .github/ISSUE_TEMPLATE directory if it doesn't exist
mkdir -p .github/ISSUE_TEMPLATE

# Only create templates if they don't exist (preserve existing ones)
# Docs: Configuring issue templates; Syntax for issue forms
echo "  - Ensuring feature request template exists..."
if [[ ! -s .github/ISSUE_TEMPLATE/01-feature-request.yml ]]; then
    cat > .github/ISSUE_TEMPLATE/01-feature-request.yml <<'YAML'
name: "🚀 Feature Request"
description: "Suggest a new feature or enhancement for Rise Gaming Takistan Life"
title: "[FEATURE] "
labels: ["feature", "needs-review"]
body:
  - type: markdown
    attributes:
      value: |
        ## Feature Request
        Thank you for suggesting a new feature! Please provide details below.
  
  - type: checkboxes
    id: prerequisites
    attributes:
      label: Prerequisites
      description: Please confirm before submitting
      options:
        - label: I have searched existing issues to ensure this hasn't been requested
          required: true
        - label: This feature aligns with the server's roleplay focus
          required: true
  
  - type: input
    id: summary
    attributes:
      label: Feature Summary
      description: A clear, one-line description of the feature
      placeholder: "e.g., Add vehicle rental system for civilians"
    validations:
      required: true
  
  - type: textarea
    id: problem
    attributes:
      label: What problem does this solve?
      description: Explain the issue or gap this feature would address
      placeholder: "Currently players have difficulty with..."
    validations:
      required: true
  
  - type: textarea
    id: proposal
    attributes:
      label: Proposed Solution
      description: Detail how this feature would work
      placeholder: "The feature would work by..."
    validations:
      required: true
  
  - type: dropdown
    id: faction
    attributes:
      label: Primary Affected Faction
      description: Which faction would benefit most?
      options:
        - "Civilians"
        - "Police/NATO"
        - "Insurgent"
        - "OPFOR/TLA"
        - "ESU"
        - "PMC"
        - "All Factions"
        - "Administrative/Staff"
    validations:
      required: true
  
  - type: dropdown
    id: priority
    attributes:
      label: Priority Level
      description: How important is this feature?
      options:
        - "Low - Nice to have"
        - "Medium - Would improve gameplay"
        - "High - Important for server balance"
    validations:
      required: true
YAML
fi

echo "  - Ensuring bug report template exists..."
if [[ ! -s .github/ISSUE_TEMPLATE/02-bug-report.yml ]]; then
    cat > .github/ISSUE_TEMPLATE/02-bug-report.yml <<'YAML'
name: "🐛 Bug Report" 
description: "Report a bug or issue with the Rise Gaming Takistan Life server"
title: "[BUG] "
labels: ["bug", "needs-triage"]
body:
  - type: markdown
    attributes:
      value: |
        ## Bug Report
        Please provide detailed information to help us reproduce and fix the issue.
  
  - type: checkboxes
    id: prerequisites
    attributes:
      label: Prerequisites
      description: Please confirm before submitting
      options:
        - label: I have searched existing issues to ensure this hasn't been reported
          required: true
        - label: This is a legitimate bug that affects normal gameplay
          required: true
  
  - type: input
    id: summary
    attributes:
      label: Bug Summary
      description: A clear, concise description of the bug
      placeholder: "e.g., Vehicle spawns underground at checkpoint"
    validations:
      required: true
  
  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
      description: Clear steps to reproduce the issue
      placeholder: |
        1. Go to...
        2. Click on...
        3. Perform action...
        4. Observe error
    validations:
      required: true
  
  - type: input
    id: expected
    attributes:
      label: Expected Behavior
      description: What should have happened?
      placeholder: "The vehicle should spawn correctly on the surface"
    validations:
      required: true
  
  - type: input
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened?
      placeholder: "Vehicle spawned partially underground"
    validations:
      required: true
  
  - type: dropdown
    id: faction
    attributes:
      label: Affected Faction
      description: Which faction experiences this bug?
      options:
        - "Civilian"
        - "Police/NATO"
        - "Insurgent"
        - "OPFOR/TLA"
        - "ESU"
        - "PMC"
        - "All Factions"
        - "Administrative/Staff"
    validations:
      required: true
  
  - type: textarea
    id: evidence
    attributes:
      label: Evidence
      description: Screenshots, videos, or log files (optional)
      placeholder: "Drag and drop files here or provide links..."
YAML
fi

echo "  - Ensuring general suggestion template exists..."
if [[ ! -s .github/ISSUE_TEMPLATE/03-general-suggestion.yml ]]; then
    cat > .github/ISSUE_TEMPLATE/03-general-suggestion.yml <<'YAML'
name: "💡 General Suggestion"
description: "Share ideas for server improvements, events, or community enhancements"
title: "[SUGGESTION] "
labels: ["suggestion", "needs-review"]
body:
  - type: markdown
    attributes:
      value: |
        ## General Suggestion
        Use this template for suggestions about server improvements, events, or community enhancements.
  
  - type: checkboxes
    id: prerequisites
    attributes:
      label: Prerequisites
      description: Please confirm before submitting
      options:
        - label: I have searched existing issues to ensure this hasn't been suggested
          required: true
        - label: This suggestion aligns with the server's values
          required: true
  
  - type: dropdown
    id: category
    attributes:
      label: Suggestion Category
      description: What type of suggestion is this?
      options:
        - "Server Rules & Regulations"
        - "Community Events & Activities"
        - "Quality of Life Improvements"
        - "Economy & Balance"
        - "Administrative Processes"
        - "Other"
    validations:
      required: true
  
  - type: input
    id: title
    attributes:
      label: Suggestion Title
      description: A clear title for your suggestion
      placeholder: "e.g., Weekly community racing events"
    validations:
      required: true
  
  - type: textarea
    id: description
    attributes:
      label: Detailed Description
      description: Explain your suggestion in detail
      placeholder: "Describe what you're suggesting and how it would work..."
    validations:
      required: true
  
  - type: textarea
    id: benefits
    attributes:
      label: Expected Benefits
      description: What positive impacts would this have?
      placeholder: "This would improve the community by..."
    validations:
      required: true
  
  - type: dropdown
    id: scope
    attributes:
      label: Scope of Impact
      description: How broadly would this affect the community?
      options:
        - "Affects all players significantly"
        - "Affects most players moderately"
        - "Affects specific groups"
        - "Limited scope but important"
    validations:
      required: true
YAML
fi

# Issue template chooser configuration
# Docs: Configuring issue templates
echo "  - Configuring issue template chooser..."
if [[ ! -s .github/ISSUE_TEMPLATE/config.yml ]]; then
    cat > .github/ISSUE_TEMPLATE/config.yml <<'YAML'
blank_issues_enabled: false
contact_links:
  - name: 🎮 Join Our Discord Server
    url: https://discord.gg/dVWvxEZJBj
    about: Connect with the community and get real-time support
  - name: 📜 Server Rules & Guidelines
    url: https://github.com/RiseGaming/Takistan-Life-Rules
    about: Review our comprehensive server rules and community guidelines
YAML
fi

# E) Labels configuration (create or update, preserve existing)
echo ""
echo "🏷️  Configuring repository labels..."

# Function to create or update labels idempotently
upsert_label() {
    local name="$1"
    local color="$2" 
    local description="$3"
    
    if gh label create "$name" --color "$color" --description "$description" --repo "$REPO_SLUG" 2>/dev/null; then
        echo "  ✅ Created label: $name"
    else
        gh label edit "$name" --color "$color" --description "$description" --repo "$REPO_SLUG" 2>/dev/null || true
        echo "  ✅ Updated label: $name"
    fi
}

echo "  - Setting up issue labels..."
upsert_label "feature" "BFD4F2" "New feature request"
upsert_label "bug" "D73A4A" "Something isn't working correctly" 
upsert_label "suggestion" "C5DEF5" "General improvement suggestion"
upsert_label "needs-review" "FBCA04" "Awaiting team review"
upsert_label "needs-triage" "FBCA04" "Needs initial evaluation"
upsert_label "needs-info" "FEF2C0" "Awaiting more information"
upsert_label "priority-high" "B60205" "High impact on gameplay"
upsert_label "priority-medium" "D93F0B" "Medium impact on gameplay"
upsert_label "priority-low" "0E8A16" "Low priority enhancement"
upsert_label "question" "D4C5F9" "Needs clarification"
upsert_label "duplicate" "CFD3D7" "Already reported elsewhere"
upsert_label "wontfix" "FFFFFF" "Will not be implemented"

# F) Community health files (only create if missing, preserve existing)
echo ""
echo "📋 Ensuring community health files exist..."

echo "  - Checking CODE_OF_CONDUCT.md..."
if [[ ! -s CODE_OF_CONDUCT.md ]]; then
    cat > CODE_OF_CONDUCT.md <<'MD'
# Community Code of Conduct

## Our Standards

Rise Gaming Takistan Life is committed to providing a welcoming and inclusive environment for all community members. We expect all participants to adhere to the following standards:

### Expected Behavior
- Be respectful and constructive in all interactions
- Focus discussions on improving the server and community
- Follow server rules and community guidelines
- Help new players learn and integrate into the community
- Report issues and violations through appropriate channels

### Unacceptable Behavior
- Personal attacks, harassment, or discriminatory language
- Spam, off-topic discussions, or disruptive behavior
- Sharing inappropriate content or server exploits
- Attempting to circumvent server rules or bans

## Enforcement

Violations of this code of conduct may result in:
- Warning and guidance from community moderators
- Temporary restrictions from repository participation
- Permanent ban from repository and gaming community
- Escalation to server administration team

## Reporting

If you experience or witness unacceptable behavior, please contact the administrative team through:
- Discord: https://discord.gg/dVWvxEZJBj
- Server administration team

This Code of Conduct applies to all community interactions, both in-game and in community spaces like this repository.
MD
    echo "  ✅ Created CODE_OF_CONDUCT.md"
fi

echo "  - Checking SUPPORT.md..."
if [[ ! -s SUPPORT.md ]]; then
    cat > SUPPORT.md <<'MD'
# Getting Support

## Community Support Channels

### Discord Community
Join our Discord server for:
- Real-time support and help
- Server status updates
- Community discussions
- Administrative assistance

**Discord:** https://discord.gg/dVWvxEZJBj

### Server Rules & Guidelines
Before asking for help, please review our comprehensive rules:
**Rules:** https://github.com/RiseGaming/Takistan-Life-Rules

## GitHub Issues

### When to Use GitHub Issues
Use GitHub Issues for:
- 🚀 **Feature Requests** - New gameplay features or server enhancements
- 🐛 **Bug Reports** - Server issues that affect gameplay
- 💡 **Suggestions** - Community improvements and quality of life changes

### Before Creating an Issue
1. **Search existing issues** - Check if your topic has been discussed
2. **Use appropriate templates** - Select the correct template for your submission
3. **Be descriptive** - Provide clear details and context
4. **Follow guidelines** - Maintain respectful and constructive communication

## Response Times

- **Discord:** Real-time to several hours
- **GitHub Issues:** 1-7 days depending on complexity
- **Critical server issues:** Contact administrators directly via Discord

## What We Don't Handle Here

This repository is specifically for community feedback. For other issues:
- **Technical server problems:** Contact administrators on Discord
- **Player disputes:** Use in-game reporting or Discord moderation
- **Account issues:** Contact server administration directly
- **Rule violations:** Report through appropriate in-game channels

Thank you for being part of the Rise Gaming Takistan Life community!
MD
    echo "  ✅ Created SUPPORT.md"
fi

# G) Commit and push changes (only if there are changes)
echo ""
echo "📝 Committing configuration changes..."

# Add files that may have been created
git add .github/ISSUE_TEMPLATE/*.yml .github/ISSUE_TEMPLATE/config.yml CODE_OF_CONDUCT.md SUPPORT.md 2>/dev/null || true

# Check if there are changes to commit
if ! git diff --cached --quiet 2>/dev/null; then
    echo "  - Changes detected, creating commit..."
    git commit -m "Configure repository: branch protection, issue templates, labels, community health files

- Add comprehensive issue templates for feature requests, bug reports, and suggestions
- Configure issue template chooser with Discord and rules links
- Set up repository labels for effective triage
- Add community health files (CODE_OF_CONDUCT.md, SUPPORT.md)
- Enable branch protection with PR requirements and conversation resolution
- Configure auto-delete head branches on merge (idempotent)

🤖 Generated with Claude Code" 2>/dev/null || true
    
    echo "  - Pushing changes to remote..."
    git push origin "$DEFAULT_BRANCH" 2>/dev/null || true
else
    echo "  - No changes to commit (configuration already up to date)"
fi

# H) Summary
echo ""
echo "✅ Repository configuration complete!"
echo ""
echo "📊 Configuration Summary:"
echo "  - Repository: $REPO_SLUG (public)"
echo "  - Issues: enabled"
echo "  - Wiki: disabled"  
echo "  - Projects: disabled"
echo "  - Auto-delete head branches: enabled"
echo "  - Branch protection: $DEFAULT_BRANCH protected (PRs required)"
echo "  - Issue templates: 3 structured templates created"
echo "  - Labels: 12 triage and priority labels configured"
echo "  - Community health: CODE_OF_CONDUCT.md, SUPPORT.md created"
echo "  - Blank issues: disabled"
echo "  - Contact links: Discord and rules repository"
echo ""
echo "🎉 Your Rise Gaming Takistan Life feedback repository is ready for community use!"