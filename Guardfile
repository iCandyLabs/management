# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :rspec do
  watch('spec/main_spec.rb') { "spec" }
  watch(%r{^lib/(.+)\.rb$})  { "spec" }
end
