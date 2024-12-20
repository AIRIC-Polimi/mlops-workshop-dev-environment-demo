# train a miniature character-level lotr model
# good for debugging and playing on macbooks and such

dataset_dir = "data/datasets/lotr"
out_dir = "out/lotr-char-gpu-big"
eval_interval = 250  # keep frequent because we'll overfit
eval_iters = 20
log_interval = 50  # don't print too too often

# we expect to overfit on this small dataset, so only save when val improves
always_save_checkpoint = False

wandb_log = False  # override via command line if you like
wandb_project = "lotr-char"
wandb_run_name = "mini-gpt"
mlflow_log = True
mlflow_experiment_name = "lotr-char"
mlflow_run_name = "mini-gpt"

dataset = "lotr_char"
gradient_accumulation_steps = 1
batch_size = 64
block_size = 128  # context of up to 64 previous characters

# baby GPT model :)
n_layer = 16
n_head = 16
n_embd = 1024
dropout = 0.2

learning_rate = 1e-3  # with baby networks can afford to go a bit higher
max_iters = 1000
lr_decay_iters = 1000  # make equal to max_iters usually
min_lr = 1e-4  # learning_rate / 10 usually
beta2 = 0.99  # make a bit bigger because number of tokens per iter is small

warmup_iters = 100  # not super necessary potentially

device = "cuda"
compile = True
