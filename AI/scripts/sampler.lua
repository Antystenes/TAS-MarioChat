--[[

   This file samples one line of characters from a trained model

   Code is based on implementation in
   https://github.com/oxford-cs-ml-2015/practical6

]]--

require 'torch'
require 'nn'
require 'nngraph'
require 'optim'
require 'lfs'

require 'util.OneHot'
require 'util.misc'

cmd = torch.CmdLine()
cmd:text()
cmd:text('Sample from a character-level language model')
cmd:text()
cmd:text('Options')
-- required:
cmd:argument('-model','model checkpoint to use for sampling')
cmd:argument('-talkdir','directory in which conversation will be stored')
-- optional parameters
cmd:option('-seed',123,'random number generator\'s seed')
cmd:option('-temperature',1,'temperature of sampling')
cmd:option('-gpuid',0,'which gpu to use. -1 = use CPU')
cmd:option('-opencl',0,'use OpenCL (instead of CUDA)')

cmd:text()

-- parse input params
opt = cmd:parse(arg)

-- check that cunn/cutorch are installed if user wants to use the GPU
if opt.gpuid >= 0 and opt.opencl == 0 then
   local ok, cunn = pcall(require, 'cunn')
   local ok2, cutorch = pcall(require, 'cutorch')
   if not ok then print('package cunn not found!') end
   if not ok2 then print('package cutorch not found!') end
   if ok and ok2 then
      print('using CUDA on GPU ' .. opt.gpuid .. '...')
      print('Make sure that your saved checkpoint was also trained with GPU. If it was trained with CPU use -gpuid -1 for sampling as well')
      cutorch.setDevice(opt.gpuid + 1) -- note +1 to make it 0 indexed! sigh lua
      cutorch.manualSeed(opt.seed)
   else
      print('Falling back on CPU mode')
      opt.gpuid = -1 -- overwrite user setting
   end
end

-- check that clnn/cltorch are installed if user wants to use OpenCL
if opt.gpuid >= 0 and opt.opencl == 1 then
   local ok, cunn = pcall(require, 'clnn')
   local ok2, cutorch = pcall(require, 'cltorch')
   if not ok then print('package clnn not found!') end
   if not ok2 then print('package cltorch not found!') end
   if ok and ok2 then
      print('using OpenCL on GPU ' .. opt.gpuid .. '...')
      print('Make sure that your saved checkpoint was also trained with GPU. If it was trained with CPU use -gpuid -1 for sampling as well')
      cltorch.setDevice(opt.gpuid + 1) -- note +1 to make it 0 indexed! sigh lua
      torch.manualSeed(opt.seed)
   else
      print('Falling back on CPU mode')
      opt.gpuid = -1 -- overwrite user setting
   end
end

torch.manualSeed(opt.seed)

-- load the model checkpoint
if not lfs.attributes(opt.model, 'mode') then
   print('Error: File ' .. opt.model .. ' does not exist. Are you sure you didn\'t forget to prepend cv/ ?')
end
checkpoint = torch.load(opt.model)
protos = checkpoint.protos
protos.rnn:evaluate() -- put in eval mode so that dropout works properly

-- initialize the vocabulary (and its inverted version)
local vocab = checkpoint.vocab
local ivocab = {}
for c,i in pairs(vocab) do ivocab[i] = c end

-- initialize the rnn state to all zeros
print('creating an ' .. checkpoint.opt.model .. '...')
local current_state
current_state = {}
for L = 1,checkpoint.opt.num_layers do
   -- c and h for all layers
   local h_init = torch.zeros(1, checkpoint.opt.rnn_size):double()
   if opt.gpuid >= 0 and opt.opencl == 0 then h_init = h_init:cuda() end
   if opt.gpuid >= 0 and opt.opencl == 1 then h_init = h_init:cl() end
   table.insert(current_state, h_init:clone())
   if checkpoint.opt.model == 'lstm' then
      table.insert(current_state, h_init:clone())
   end
end
state_size = #current_state

-- infinite sampling loop
local last_line_c = 1
local line_count = 1
local last_msg
while true do
   for i = last_line_c,9999 do
      local msg_file = opt.talkdir .. '/' .. i
      if not path.exists(msg_file) then
         line_count = i-1
         break
      end
   end
   last_line_c = line_count + 3
   while true do
      -- check if conversation is over
      if path.exists(opt.talkdir .. '/end') or not path.exists(opt.talkdir) then
         os.exit()
      end

      -- read user's line
      local msg_file = opt.talkdir .. '/' .. line_count

      if path.exists(msg_file) then
         local msg_file_handle = io.open(msg_file, 'rb')
         last_msg = msg_file_handle:read('*a') .. '\n'
         msg_file_handle:close()
         break
      end
      os.execute('sleep 0.2')
   end

   -- feed lstm network with last_msg
   for c in last_msg:gmatch'.' do
      prev_char = torch.Tensor{vocab[c]}
      if opt.gpuid >= 0 and opt.opencl == 0 then prev_char = prev_char:cuda() end
      if opt.gpuid >= 0 and opt.opencl == 1 then prev_char = prev_char:cl() end
      local lst = protos.rnn:forward{prev_char, unpack(current_state)}
      -- lst is a list of [state1,state2,..stateN,output]. We want everything but last piece
      current_state = {}
      for i=1,state_size do table.insert(current_state, lst[i]) end
      prediction = lst[#lst] -- last element holds the log probabilities
   end

   -- sample lstm network to last_msg
   last_msg = ''
   while true do
      -- log probabilities from the previous timestep
      prediction:div(opt.temperature) -- scale by temperature
      local probs = torch.exp(prediction):squeeze()
      probs:div(torch.sum(probs)) -- renormalize so probs sum to one
      prev_char = torch.multinomial(probs:float(), 1):resize(1):float()

      -- forward the rnn for next character
      local lst = protos.rnn:forward{prev_char, unpack(current_state)}
      current_state = {}
      for i=1,state_size do table.insert(current_state, lst[i]) end
      prediction = lst[#lst] -- last element holds the log probabilities

      local c = ivocab[prev_char[1]]
      if c == '\n' then break end

      last_msg = last_msg .. c
   end

   -- write bot's line
   local msg_file = opt.talkdir .. '/' .. (line_count + 1)
   local msg_file_handle = io.open(msg_file, 'w')
   msg_file_handle:write(last_msg)
   msg_file_handle:flush()
   msg_file_handle:close()

   line_count = line_count + 2;
end
