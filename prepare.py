"""
Prepare the Shakespeare dataset for character-level language modeling.
So instead of encoding with GPT-2 BPE tokens, we just map characters to ints.
Will save train.bin, val.bin containing the ids, and meta.pkl containing the
encoder and decoder and some other related info.
"""
import os
import pickle
import numpy as np
from common import DATA_PATH

# configuration
dataset_name = 'lotr'  # TODO: make param
input_file_path = os.path.join(DATA_PATH, 'raw', f'{dataset_name}.txt')
output_dataset_dir = os.path.join(DATA_PATH, 'datasets', dataset_name)

# download the raw dataset
with open(input_file_path, 'r') as f:
    data = f.read()
print(f"length of dataset in characters: {len(data):,}")

# get all the unique characters that occur in this text
chars = sorted(list(set(data)))
vocab_size = len(chars)
print("all the unique characters:", ''.join(chars))
print(f"vocab size: {vocab_size:,}")

# create a mapping from characters to integers
stoi = { ch:i for i,ch in enumerate(chars) }
itos = { i:ch for i,ch in enumerate(chars) }
def encode(s):
    return [stoi[c] for c in s] # encoder: take a string, output a list of integers
def decode(l):
    return ''.join([itos[i] for i in l]) # decoder: take a list of integers, output a string

# create the train and test splits
n = len(data)
train_data = data[:int(n*0.9)]
val_data = data[int(n*0.9):]

# encode both to integers
train_ids = encode(train_data)
val_ids = encode(val_data)
print(f"train has {len(train_ids):,} tokens")
print(f"val has {len(val_ids):,} tokens")

# export to bin files
train_ids = np.array(train_ids, dtype=np.uint16)
val_ids = np.array(val_ids, dtype=np.uint16)
os.makedirs(output_dataset_dir, exist_ok=True)
train_ids.tofile(os.path.join(output_dataset_dir, 'train.bin'))
val_ids.tofile(os.path.join(output_dataset_dir, 'val.bin'))

# save the meta information as well, to help us encode/decode later
meta = {
    'vocab_size': vocab_size,
    'itos': itos,
    'stoi': stoi,
}
with open(os.path.join(output_dataset_dir, 'meta.pkl'), 'wb') as f:
    pickle.dump(meta, f)

# length of dataset in characters:  3,260,499
# all the unique characters:
#  !"#&'()*,-./0123456789:;<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZ_`abcdefghijklmnopqrstuvwxyz}¢¤¥«®µ»ó–—‘’‚…
# vocab size: 99
# train has 2,934,449 tokens
# val has 326,050 tokens