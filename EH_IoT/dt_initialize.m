function net = dt_initialize(input_size,output_size,options)
%DT_INITIALIZE Trainable causal multi-head transformer in base MATLAB.
% Every parameter, including attention projections and layer norms, is learned.
% No Deep Learning Toolbox or external model weights are required.
d=options.d_model;
assert(mod(d,options.heads)==0,'d_model must be divisible by heads.');
net.input_size=input_size; net.output_size=output_size;
net.d_model=d; net.heads=options.heads; net.blocks=options.blocks;
net.context=options.context; p=struct();
p.Win=xavier(input_size,d); p.bin=zeros(1,d);
for b=1:net.blocks
    prefix=sprintf('b%d_',b);
    for name={'Wq','Wk','Wv','Wo'}, p.([prefix name{1}])=xavier(d,d); end
    p.([prefix 'W1'])=xavier(d,options.ff_size);
    p.([prefix 'b1'])=zeros(1,options.ff_size);
    p.([prefix 'W2'])=xavier(options.ff_size,d);
    p.([prefix 'b2'])=zeros(1,d);
    p.([prefix 'g1'])=ones(1,d); p.([prefix 'z1'])=zeros(1,d);
    p.([prefix 'g2'])=ones(1,d); p.([prefix 'z2'])=zeros(1,d);
end
p.Wout=0.02*randn(d,output_size); p.bout=zeros(1,output_size);
net.parameters=p;
end

function w=xavier(m,n)
w=randn(m,n)*sqrt(2/(m+n));
end
