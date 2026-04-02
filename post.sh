#!/bin/bash
source ~/.bashrc
# openclaw config set agents.defaults.exec.security full
openclaw config set execApprovals.approvers '["637458526855233547"]'
openclaw gateway restart
openclaw doctor
openclaw status --deep
