
function synth(
    spatial_modes,
    temporal_modes,
    center,
    xvals,
    coefficients,
    cormat,
    vars;
    corthresh = 0.6,
)

    ntrials = size(cormat, 2)

    abscormat = abs.(cormat)
    maxcor = maximum(abscormat, dims = 1)[1, :]
    maxcoridx = mapslices(argmax, abscormat, dims = 1)[1, :]

    proctrials = findall(x -> x >= corthresh, maxcor)

    np = length(proctrials)
    ntime = size(xvals,2)[1]
    spaceshp = size(center)
    nspace = prod(spaceshp)
    nmodes = size(spatial_modes,3)[1]

    # tempout = zeros(
    #     Union{Missing,Float64},
    #     size(spatial_modes)[1:2]...,
    #     size(xvals, 2),
    #     length(proctrials),
    # )

    yvals = zeros(ntime,np)

    for (i, idx) in enumerate(proctrials)

        bestidx = maxcoridx[idx]

        model = Polynomial(coefficients[:, idx])

        yvals[:,i] = model.(xvals[bestidx, :])
    end

    # vars = [0.308162,0.227067,0.195983,0.174960,0.093828]
    varscale = vars[proctrials] / sum(vars[proctrials])



    sm = reshape(spatial_modes,(nspace,nmodes))

    out_ = (yvals .* reshape(varscale,(1,np))) * sm[:,proctrials]'
    # out_ = yvals * sm[:,proctrials]'

    out = reshape(transpose(out_),(spaceshp...,ntime)) .+ reshape(center, (spaceshp..., 1))

    return out
end

function extractwater(img::Array{<:Any,2}; init_thresh = -16)
    binary = img .< init_thresh

    invalidx = findall(x->ismissing(x),binary)
    binary[invalidx] .= 0

    diff1, diff2 = Kernel.sobel()

    xedges = imfilter(binary,diff1)
    yedges = imfilter(binary,diff2)
    edgeimg = @. sqrt(xedges^2 + yedges^2)

    # imgm = (mapwindow(maximum, edgeimg .> 0.5, (11,11))) .& (.!ismissing.(img))
    imgm = (mapwindow(maximum, edgeimg .> 0.5, (11,11)))

    fill_img =img[:,:]
    fill_img[invalidx] = rand(init_thresh*2:0.005:init_thresh,length(invalidx))

    sampleidx = findall(imgm)
    # samples = img[sampleidx]
    samples = fill_img[sampleidx]

    edges, counts = HistogramThresholding.build_histogram(Float32.(samples),500)

    t = find_threshold(counts[1:end], edges, Otsu())

    return img .< t

end

# diff = est .+ ( obs .* 2)
# 0 = both no water
# 1 = est water, obs no water
# 2 = est no water, obs water
# 3 = both water
