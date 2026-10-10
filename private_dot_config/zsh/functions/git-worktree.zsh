gwt() {
    local branch=""
    local worktree_path=""
    local switch_immediately=false
    local create_new_branch=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--switch)
                switch_immediately=true
                shift
                ;;
            -b|--new-branch)
                create_new_branch=true
                shift
                ;;
            *)
                if [[ -z "$branch" ]]; then
                    branch="$1"
                elif [[ -z "$worktree_path" ]]; then
                    worktree_path="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$branch" ]]; then
        echo "Usage: gwt [-s|--switch] [-b|--new-branch] <branch-name> [worktree-path]"
        echo "  -s, --switch      Switch to the new tmux session immediately"
        echo "  -b, --new-branch  Create a new branch"
        return 1
    fi
    
    # Default path if not specified
    worktree_path="${worktree_path:-../$(basename $(pwd))-$branch}"
    
    # Create the worktree
    echo "Creating worktree at $worktree_path for branch $branch..."
    if $create_new_branch; then
        git worktree add -b "$branch" "$worktree_path"
    else
        git worktree add "$worktree_path" "$branch" 2>/dev/null || git worktree add -b "$branch" "$worktree_path"
    fi
    
    if [[ $? -eq 0 ]]; then
        local abs_path=$(cd "$worktree_path" && pwd)
        local session_name="wt-$branch"
        
        # Create new tmux session
        tmux new-session -d -s "$session_name" -c "$abs_path"
        
        # Set up clean session
        tmux send-keys -t "$session_name" "mise trust 2>/dev/null || true" C-m
        sleep 0.1
        tmux send-keys -t "$session_name" "clear" C-m
        
        echo "✓ Worktree created at: $abs_path"
        echo "✓ Tmux session '$session_name' created"
        
        if $switch_immediately && [[ -n "$TMUX" ]]; then
            echo "✓ Switching to session..."
            tmux switch-client -t "$session_name"
        else
            echo ""
            echo "To switch: tmux switch-client -t $session_name"
        fi
    fi
}

# List all worktree sessions
gwt-list() {
    echo "Git worktrees:"
    git worktree list
    echo ""
    echo "Tmux worktree sessions:"
    tmux list-sessions 2>/dev/null | grep "^wt-" || echo "  No worktree sessions found"
}

# Clean up: remove worktree and its tmux session
gwt-remove() {
    local branch="$1"
    if [[ -z "$branch" ]]; then
        echo "Usage: gwt-remove <branch-name>"
        return 1
    fi
    
    # Find worktree path
    local worktree_path=$(git worktree list | grep "\[$branch\]" | awk '{print $1}')
    
    if [[ -n "$worktree_path" ]]; then
        echo "Removing worktree at $worktree_path..."
        git worktree remove "$worktree_path"
    fi
    
    # Kill tmux session if it exists
    if tmux has-session -t "wt-$branch" 2>/dev/null; then
        echo "Killing tmux session wt-$branch..."
        tmux kill-session -t "wt-$branch"
    fi
}