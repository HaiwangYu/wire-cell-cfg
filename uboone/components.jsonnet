// This provides default component configurations for MicroBoone.
// They can be aggregated as-is or extended/customized in the
// top-level configuration file.  They make use of uboone global
// parameters.

local params = import "uboone/globals.jsonnet";
local wc = import "wirecell.jsonnet";
{
    anode: {
        type : "AnodePlane",
        name : "uboone-anode-plane", // could leave empty, just testing out explicit name
        data : {
            // WIRECELL_PATH will be searched for these files
            wires:"microboone-celltree-wires-v2.json.bz2",
            fields:"garfield-1d-3planes-21wires-6impacts-v6.json.bz2",
            ident : 0,
            gain : params.gain,
            shaping : params.shaping,
            postgain: params.postgain,
            readout_time : params.readout,
            tick : params.tick,
        }
    },
    
    // shortcut type+name for below
    anode_tn: self.anode.type + ":" + self.anode.name,

    drifter: {
        type : "Drifter",
        data : {
            anode: $.anode_tn,
            DL : params.DL,
            DT : params.DT,
            lifetime : params.electron_lifetime,
            fluctuate : params.fluctuate,
        }
    },

    ductor: {
        type : 'Ductor',
        data : {
            nsigma : params.nsigma_diffusion_truncation,
            fluctuate : params.fluctuate,
            start_time: params.start_time,
            readout_time: params.readout,
            drift_speed : params.drift_speed,
            first_frame_number: params.start_frame_number,
            anode: $.anode_tn,
        }
    },        


    noise : {
        type: "SilentNoise",
        data: {},
    },


    digitizer : {
        type: "Digitizer",
        data : {
            gain: -1.0,
            baselines: [900*wc.millivolt,900*wc.millivolt,200*wc.millivolt],
            resolution: 12,
            fullscale: [0*wc.volt, 2.0*wc.volt],
            anode: $.anode_tn,
        }
    },

    fourdee : {
        type : 'FourDee',
        data : {
            DepoSource: "TrackDepos",
            Drifter: "Drifter",
            Ductor: "Ductor",
            Dissonance: "SilentNoise",
            Digitizer: "Digitizer",
            FrameSink: "DumpFrames",            
        }
    },

}