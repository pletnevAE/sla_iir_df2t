%================================================================================
% This function writes data to the specified file in the specified format 
% (bin, hex, dec).
%================================================================================
function write_file(file, data, format)
    fid = fopen(file, 'w'); % File descriptor
    if fid == -1
        error('Failed to open file for writing: %s', file);
    end
    
    %================================================================================
    %% Selecting a data type
    %================================================================================
    switch lower(format)
        case 'hex'
            vals = hex(data);
            for i = 1:length(data)
                fprintf(fid, '%s\n', vals(i, :));
            end
        case 'bin'
            vals = bin(data);
            for i = 1:length(data)
                fprintf(fid, '%s\n', vals(i, :));
            end
        case 'dec'
            vals = int(data);
            for i = 1:length(data)
                fprintf(fid, '%d\n', vals(i));
            end
        otherwise
            fclose(fid);
            error('Unknown data format. Use hex, dec or bin.')
    end
    fclose(fid);
end