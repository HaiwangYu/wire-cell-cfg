local wc = import "wirecell.jsonnet";
local g = import "pgraph.jsonnet";

local par = import "params.jsonnet";
local com = import "common.jsonnet";
local chndb = import "chndb.jsonnet";



local make_obnf(chndbobj) = {
    local bitshift = {
        type: "mbADCBitShift",
        data: {
            Number_of_ADC_bits: 12,
            Exam_number_of_ticks_test: 500,
            Threshold_sigma_test: 7.5,
            Threshold_fix: 0.8,
        },
    },
    local status = {
        type: "mbOneChannelStatus",
        data: {
            Threshold: 3.5,
            Window: 5,
            Nbins: 250,
            Cut: 14,
        },            
    },
    local single = {
        type: "mbOneChannelNoise",
        data: {
            noisedb: wc.tn(chndbobj),
        }
    },
    local grouped = {
        type: "mbCoherentNoiseSub",
        data: {
            noisedb: wc.tn(chndbobj),
        }
    },

    ret: g.pnode({
        type: "OmnibusNoiseFilter",
        data : {

            maskmap: { chirp: "bad", noisy: "bad" },
            channel_filters: [
                wc.tn(bitshift),
                wc.tn(single)
            ],
            grouped_filters: [
                wc.tn(grouped),
            ],
            channel_status_filters: [
                wc.tn(status),
            ],
            noisedb: wc.tn(chndbobj),
            intraces: "orig",
            outtraces: "quiet",
        }
    }, uses=[chndbobj, single, grouped, bitshift, status], nin=1, nout=1)
};

local pmtfilter = g.pnode({
    type: "OmnibusPMTNoiseFilter",
    data: {
        intraces: "quiet",
        outtraces: "raw",
    }
}, nin=1, nout=1);

local make_nf(obnf,name="") = g.intern([obnf], [pmtfilter],
                                       edges = [ g.edge(obnf, pmtfilter) ],
                                       name = "NoiseFilter%s"%name);

// this produces a dictionry with the same keys as chndb but with each
// value replaced with a "noise filter" pnode.
std.mapWithKey(function(name, dbobj) make_nf(make_obnf(dbobj).ret, name), chndb)
