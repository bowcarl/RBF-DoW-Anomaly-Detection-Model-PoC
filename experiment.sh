#!/bin/bash
# run_experiment.sh
# Usage: ./run_experiment.sh [slow_leech|blast|geometric|random|validate]

SESSION="k6run"
BASE_URL="https://ezrgx1xle1.execute-api.eu-north-1.amazonaws.com"
REGION="eu-north-1"
EVENTBRIDGE_RULE="triggerRate"
ATTACK=${1:-slow_leech}

case $ATTACK in
  slow_leech) ATTACK_SCRIPT="slow_leech_attack.js" ; DURATION=86400 ;;
  blast)      ATTACK_SCRIPT="blast_attack.js"       ; DURATION=14400 ;;
  geometric)  ATTACK_SCRIPT="geometric_leech.js"    ; DURATION=86400 ;;
  random)     ATTACK_SCRIPT="random_leech.js"        ; DURATION=86400 ;;
  validate)   ATTACK_SCRIPT=""                       ; DURATION=3600  ;;
  *)
    echo "Unknown attack: $ATTACK"
    echo "Usage: ./run_experiment.sh [slow_leech|blast|geometric|random|validate]"
    exit 1
    ;;
esac

echo "================================================"
echo "Starting experiment: $ATTACK"
echo "================================================"

# ── Enable EventBridge ────────────────────────────────────────────
echo "Enabling EventBridge rule: $EVENTBRIDGE_RULE..."
aws events enable-rule --name $EVENTBRIDGE_RULE --region $REGION
echo "EventBridge enabled."

tmux kill-session -t $SESSION 2>/dev/null
tmux new-session -d -s $SESSION -n normal

# ── Validate mode ─────────────────────────────────────────────────
if [ "$ATTACK" = "validate" ]; then
  tmux send-keys -t $SESSION:normal \
    "k6 run -e BASE_URL=$BASE_URL --stage '1h:50' normal.js 2>&1 | tee validate_normal.log" Enter

  echo "Normal-only validation running for 1 hour..."
  sleep $DURATION

  echo "Disabling EventBridge rule: $EVENTBRIDGE_RULE..."
  aws events disable-rule --name $EVENTBRIDGE_RULE --region $REGION
  tmux kill-session -t $SESSION 2>/dev/null
  echo "Done. Check MitigationLog — expect zero THROTTLE_APPLIED entries."
  exit 0
fi

# ── Attack mode ───────────────────────────────────────────────────
tmux new-window -t $SESSION -n attack

tmux send-keys -t $SESSION:normal \
  "k6 run -e BASE_URL=$BASE_URL normal.js 2>&1 | tee normal_${ATTACK}.log" Enter

sleep 30

tmux send-keys -t $SESSION:attack \
  "k6 run -e BASE_URL=$BASE_URL $ATTACK_SCRIPT 2>&1 | tee attack_${ATTACK}.log" Enter

echo "Both scripts running. Waiting $DURATION seconds..."
echo "To watch: tmux attach -t $SESSION:normal"
echo "To detach: Ctrl+B then D"

# Wait for the experiment duration then auto-disable
sleep $DURATION

echo ""
echo "Experiment complete. Disabling EventBridge rule: $EVENTBRIDGE_RULE..."
aws events disable-rule --name $EVENTBRIDGE_RULE --region $REGION
tmux kill-session -t $SESSION 2>/dev/null
echo "EventBridge disabled. Export your fingerprints table now."