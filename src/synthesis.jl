
function synth(
    spatial_modes,
    temporal_modes,
    center,
    xvals,
    coefficients,
    cormat;
    corthresh = 0.6,
)

    ntrials = size(cormat, 2)

    abscormat = abs.(cormat)
    maxcor = maximum(abscormat, dims = 1)[1, :]
    maxcoridx = mapslices(argmax, abscormat, dims = 1)[1, :]

    proctrials = findall(x -> x >= corthresh, maxcor)

    tempout = zeros(
        Union{Missing,Float64},
        size(spatial_modes)[1:2]...,
        size(xvals, 2),
        length(proctrials),
    )

    @inbounds for (i, idx) in enumerate(proctrials)

        bestidx = maxcoridx[idx]

        model = Polynomial(coefficients[:, idx])

        yvals = model.(xvals[bestidx, :])

        # invert the spatial modes if there is a negative correlation
        if cormat[bestidx, idx] < -1
            sm = spatial_modes[:, :, idx] * -1
        else
            sm = spatial_modes[:, :, idx]
        end

        tempout[:, :, :, i] = sm .* reshape(yvals, (1, 1, size(yvals)...))
    end

    out = sum(tempout, dims = 4)[:, :, :, 1]
    out .+= reshape(center, (size(center)..., 1))

    return out
end

function extractwater(img::Array{<:Any,2})

    valididx = findall(x -> x !== missing, img)

    invalididx = findall(x -> ismissing(x), img)

    edges, counts = build_histogram(Float32.(img[idx]),256)

end
