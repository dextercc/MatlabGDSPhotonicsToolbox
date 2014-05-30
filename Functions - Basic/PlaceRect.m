function [structure, info, infoInput] = PlaceRect(structure, info, len, wid, layer, datatype, varargin)

%PLACERECT places rectangular polygons in a gds structure
%Author : Nicolas Ayotte                                     Creation date : 28/11/2013
%
%     This function receives an input GDS structure and the parameters for one or many
%     rectangles to create and place at positions and orientations determined by the info
%     variable. It then updates info to the output positions.
%
%     [struct, info, infoInput] = PlaceRect(struct, info, len, wid, layer, datatype)
%     [struct, info] = PlaceRect(struct, info, len, wid, layer, datatype, 'endwidth', widEnd)
%
%     ARGUMENT NAME     SIZE        DESCRIPTION
%     len               m|1 x 1     rect length
%     wid               m|1 x n|1   rect widths
%     layer             m|1 x n     layers
%     datatype          m|1 x n     datatypes
%     info.pos          m x 2       current position
%     info.ori          m|1 x 1     orientation angle in degrees
%     infoInput.pos     m x 2       input position
%     infoInput.ori     m|1 x 1     inverse of input orientation
% 
%     OPTION NAME       SIZE        DESCRIPTION
%     'offset'          m|1         [] vertical offset of output
%     'endwidth'        m|1 x n|1   [wid] rect end widths
%     'invert'          bool        [false] flip along the propagation direction
%     'group'           bool        [false] grouping waveguides (used for shorten)
%     'shorten'         1           [0] send turn radius to shorthen for a 90 degrees turn
%
%     See also PlaceArc, PlaceTaper, PlaceSBend

rows = size(info.pos, 1);
cols = size(layer, 2);


%% Default value for valid options
rect.offset = zeros(rows, 1);
rect.endwidth = wid;
rect.invert = false;
rect.group = false;
rect.shorten = 0;
rect = ReadOptions(rect, varargin{ : });


%% Arguments validation
NonNegative(len, wid);
[len, wid, layer, datatype, info.ori, rect.offset, rect.endwidth] = NumberOfRows(rows, len, wid, layer, datatype, info.ori, rect.offset, rect.endwidth);
[wid, datatype] = NumberOfColumns(cols, wid, datatype);
infoInput = InvertInfo(info);


%% Group guides
if(rect.group && rows > 1)
  [info, originalOrder] = CheckParallelAndNormal(info);
  Equal(len);
  if(rect.shorten ~= 0)
    shortenLength = InfoWidth(info, struct('w', max(wid))) + rect.shorten - max(max(wid)/2);
    len = len - shortenLength;
  end
end


%% Rectangle elements
dwidth = 0.5 * (rect.endwidth - wid);    % make endwidth a differential value

rectEl = cell(1, rows * cols);
for row = 1 : rows
  if(len(row) > 1e-6)
    x1 = 0;
    x2 = len(row);
    for col = 1 : cols
      if(wid(row, col) > 1e-6)
        y1 = 0.5 * wid(row, col);
        y2 = -0.5 * wid(row, col);
        if(rect.invert)
          xy = [[x1; x2; x2; x1; x1], [y1 + dwidth(row, col); y1 + rect.offset(row) ; y2 + rect.offset(row); y2 - dwidth(row, col); y1] + dwidth(row, col)];
        else
          xy = [[x1; x2; x2; x1; x1], [y1; y1 + rect.offset(row) + dwidth(row, col); y2 + rect.offset(row) - dwidth(row, col); y2; y1]];
        end
        rectEl{row + (col - 1) * rows} = gds_element('boundary', 'xy', RotTransXY(xy, info.pos(row, : ), info.ori(row)), 'layer', layer(row, col), 'dtype', datatype(row, col));
      end
    end
  end
end
structure = add_element(structure, rectEl(cellfun(@(x)~isempty(x), rectEl)));
info.pos = info.pos + RotTransXY([len, rect.offset], [0, 0], info.ori);

if(isempty(info.length)); info.length = zeros(rows, length(info.neff)); end
info.length = info.length + repmat(len, 1, length(info.neff)) .* repmat(info.neff, rows, 1);

if(rect.group && rows > 1)
  info = SplitInfo(info, originalOrder);  % Put info back in its original order
end

end
