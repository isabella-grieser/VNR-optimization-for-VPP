using FileIO, Colors, FixedPointNumbers

function make_gif(type, loads)
      #save the pictures as a gif
  A = []

  for l in loads
    img_path = string(pwd()*"\\fig\\result_"*type*"_"*l*".png")
    ima = load(img_path)
    push!(A, ima)
  end
  save("test.gif", A)
end

lo = ["01", "02", "03", "04", "05", "06", "07", "08","09","10","11","12"]

make_gif("exact", lo)