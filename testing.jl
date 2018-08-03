using Pkg

# Pkg REPL mode
begin
pkg"registry add https://github.com/fredrikekre/Registry.git"
pkg"registry add General"
pkg"registry st"
pkg"registry rm General"
pkg"registry add 23338594-aafe-5451-b93e-139f81909106"
pkg"registry rm 23338594-aafe-5451-b93e-139f81909106"
pkg"registry add General=23338594-aafe-5451-b93e-139f81909106"
pkg"registry rm General=23338594-aafe-5451-b93e-139f81909106"
pkg"registry add General"
pkg"registry up Registry"
pkg"registry up ae0cb698-197b-42ec-a0a0-4f871aea6013"
pkg"registry up Registry=ae0cb698-197b-42ec-a0a0-4f871aea6013"
end
# Registry API
