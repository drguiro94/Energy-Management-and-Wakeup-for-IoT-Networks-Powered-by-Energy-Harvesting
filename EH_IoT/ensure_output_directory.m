function ensure_output_directory(path)
%ENSURE_OUTPUT_DIRECTORY Handle a shared-parent race in split-count runs.
if exist(path,'dir'), return; end
[ok,message]=mkdir(path);
if ~ok && ~exist(path,'dir')
    % Another worker may just have created the parent directory.
    [ok,message]=mkdir(path);
    if ~ok && ~exist(path,'dir'), error('Cannot create output directory: %s',message); end
end
end
