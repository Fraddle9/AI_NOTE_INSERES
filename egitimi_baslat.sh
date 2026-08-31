#!/bin/bash
mlx_lm.lora --model mlx-community/Meta-Llama-3-8B-Instruct-4bit --train --data ./veri --iters 500 --batch-size 2 --num-layers 16
