// This is a WCT configuration file for use in a WC/LS job.  It is
// expected to be named inside a FHiCL configuration.  That
// configuration must supply the names of converter components as
// "depo_source" and "frame_sink" external variables.
//

local wc = import "wirecell.jsonnet";
local g = import "pgraph.jsonnet";


local params = import "pgrapher/experiment/uboone/simparams.jsonnet";
local tools_maker = import "pgrapher/common/tools.jsonnet";
local tools = tools_maker(params);
local sim_maker = import "pgrapher/experiment/uboone/sim.jsonnet";
local sim = sim_maker(params, tools);

local wcls_maker = import "pgrapher/ui/wcls/nodes.jsonnet";
local wcls = wcls_maker(params, tools);

// for dumping numpy array for debugging
local io = import "pgrapher/common/fileio.jsonnet";

local nf_maker = import "pgrapher/experiment/uboone/nf.jsonnet";
local chndb_maker = import "pgrapher/experiment/uboone/chndb.jsonnet";

local sp_maker = import "pgrapher/experiment/uboone/sp.jsonnet";

    
// This tags the output frame of the WCT simulation and is used in a
// couple places so define it once.
local sim_adc_frame_tag = "orig";

// Collect the WC/LS input converters for use below.  Make sure the
// "name" matches what is used in the FHiCL that loads this file.
local wcls_input = {
    depos: wcls.input.depos(name=""),
};

// Collect all the wc/ls output converters for use below.  Note the
// "name" MUST match what is used in theh "outputers" parameter in the
// FHiCL that loads this file.
local wcls_output = {
    // ADC output from simulation
    sim_digits: wcls.output.digits(name="simdigits", tags=[sim_adc_frame_tag]),
    
    // The noise filtered "ADC" values.  These are truncated for
    // art::Event but left as floats for the WCT SP.  Note, the tag
    // "raw" is somewhat historical as the output is not equivalent to
    // "raw data".
    nf_digits: wcls.output.digits(name="nfdigits", tags=["raw"]),

    // The output of signal processing.  Note, there are two signal
    // sets each created with its own filter.  The "gauss" one is best
    // for charge reconstruction, the "wiener" is best for S/N
    // separation.  Both are used in downstream WC code.
    sp_signals: wcls.output.signals(name="spsignals", tags=["gauss"]),
};


local anode = tools.anodes[0];
local drifter = sim.drifter;

// Signal simulation.
local ductors = sim.make_anode_ductors(anode);
local md_pipes = sim.multi_ductor_pipes(ductors);
local ductor = sim.multi_ductor_graph(anode, md_pipes, "mdg");

local miscon = sim.misconfigure(params);

// Noise simulation adds to signal.
local noise_model = sim.make_noise_model(anode, sim.empty_csdb);
local noise = sim.add_noise(noise_model);

local digitizer = sim.digitizer(anode, tag="orig");



//local noise_epoch = "perfect";
local noise_epoch = "after";
local chndb = chndb_maker(params, tools).wct(noise_epoch);
local nf = nf_maker(params, tools, chndb);

// signal processing
local sp = sp_maker(params, tools);


local sink = sim.frame_sink;

local graph = g.pipeline([wcls_input.depos,
                          drifter, ductor, miscon, noise, digitizer,
                          wcls_output.sim_digits,
                          nf,
                          wcls_output.nf_digits,
                          sp,
                          wcls_output.sp_signals,
                          sink]);


local app = {
    type: "Pgrapher",
    data: {
        edges: graph.edges,
    },
};

// Finally, the configuration sequence which is emitted.

graph.uses + [app]