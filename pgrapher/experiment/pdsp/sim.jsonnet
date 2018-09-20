local wc = import "wirecell.jsonnet";
local g = import "pgraph.jsonnet";
local f = import "pgrapher/common/funcs.jsonnet";
local sim_maker = import "pgrapher/common/sim/nodes.jsonnet";


// return some nodes, includes base sim nodes.
function(params, tools) {
    local sim = sim_maker(params, tools),

    local nanodes = std.length(tools.anodes),

    // I rue the day that we must have an (anode) X (field) cross product!
    local ductors = sim.make_detector_ductors("nominal", tools.anodes, tools.pirs[0]),

    local bagger = g.pnode({
        type:'DepoBagger',
        name:'bagger',
        data: {
            gate: [params.sim.ductor.start_time,
                   params.sim.ductor.start_time+params.sim.ductor.readout_time],
        },
    }, nin=1, nout=1),

    local dsfanout = g.pnode({
        type:"DepoSetFanout",
        name:"fanout",
        data:{
            multiplicity: nanodes,
        },
    }, nin=1, nout=nanodes),

    local make_zipper = function(name, anode, pirs, type='DepoZipper') g.pnode({
        type:type,
        name:name,
        data: {
            rng: wc.tn(tools.random),
            anode: wc.tn(anode),
            pirs: std.map(function(pir) wc.tn(pir), pirs),
            fluctuate: params.sim.fluctuate,
            drift_speed: params.lar.drift_speed,
            first_frame_number: params.daq.first_frame_number,
            readout_time: params.sim.ductor.readout_time,
            start_time: params.sim.ductor.start_time,
            tick: params.daq.tick,
            nsigma: 3,
        },
    }, nin=1, nout=1, uses=[anode] + pirs),
    local zippers = [make_zipper("depozipper%d"%n, tools.anodes[n], tools.pirs[0])
                     for n in std.range(0, nanodes-1)],
    local transforms = [make_zipper("depotransform%d"%n, tools.anodes[n], tools.pirs[0], 'DepoTransform')
                     for n in std.range(0, nanodes-1)],
    local depos2traces = transforms,


    local digitizers = [
        sim.digitizer(tools.anodes[n], name="digitizer%d"%n)
        for n in std.range(0,nanodes-1)],

    local reframers = [
        g.pnode({
            type: 'Reframer',
            name: 'reframer%d'%n,
            data: {
                anode: wc.tn(tools.anodes[n]),
                tags: [],           // ?? what do?
                fill: 0.0,
                tbin: params.sim.reframer.tbin,
                toffset: 0,
                nticks: params.sim.reframer.nticks,
            },
        }, nin=1, nout=1) for n in std.range(0, nanodes-1)],


    // fixme: see https://github.com/WireCell/wire-cell-gen/issues/29
    local make_noise_model = function(anode, csdb=null) {
        type: "EmpiricalNoiseModel",
        name: "empericalnoise%s"% anode.name,
        data: {
            anode: wc.tn(anode),
            chanstat: if std.type(csdb) == "null" then "" else wc.tn(csdb),
            spectra_file: params.files.noise,
            nsamples: params.daq.nticks,
            period: params.daq.tick,
            wire_length_scale: 1.0*wc.cm, // optimization binning
        },
        uses: [anode] + if std.type(csdb) == "null" then [] else [csdb],
    },
    local noise_models = [make_noise_model(anode) for anode in tools.anodes],


    local add_noise = function(model) g.pnode({
        type: "AddNoise",
        name: "addnoise%s"%[model.name],
        data: {
            rng: wc.tn(tools.random),
            model: wc.tn(model),
            replacement_percentage: 0.02, // random optimization
        }}, nin=1, nout=1, uses=[model]),

    local noises = [add_noise(model) for model in noise_models],

    ret : {

        bagger: bagger, 

        signal_pipelines: [g.pipeline([depos2traces[n], reframers[n],  digitizers[n]],
                                      name="simsigpipe%d"%n) for n in std.range(0, nanodes-1)],

        splusn_pipelines:  [g.pipeline([depos2traces[n], reframers[n], noises[n], digitizers[n]],
                                       name="simsignoipipe%d"%n) for n in std.range(0, nanodes-1)],
    
        signal: f.fanpipe('DepoSetFanout', self.signal_pipelines, 'FrameFanin', "simsignalgraph"),
        splusn: f.fanpipe('DepoSetFanout', self.splusn_pipelines, 'FrameFanin', "simsplusngraph"),

    } + sim,                    // tack on base for user sugar.
}.ret
