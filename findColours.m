% my_colors = findColours1('images\org_1.png');

function res=findColours(filename)

% Load and filter the image
importedImage = loadImage(filename);
% Find the position of the reference black circles
circleCenters = findCircles(importedImage);
% Correct the image to standard view
filteredImageDouble = correctImage(circleCenters, importedImage);

% Get the final matrix
res = getColors(filteredImageDouble);

disp(res)

% % Display the filtered image
% figure;
% imshow(importedImage);
% title('Filtered Image');

end

function filteredImageMedGau = loadImage(filename)
% Read the image
importedImage = imread(filename);

% Remove noise

% Define a larger neighborhood size for more smoothing
neighborhoodSize = [7 7];

% Apply median filter to each color channel separately
redChannelFiltered = medfilt2(importedImage(:, :, 1), neighborhoodSize);
greenChannelFiltered = medfilt2(importedImage(:, :, 2), neighborhoodSize);
blueChannelFiltered = medfilt2(importedImage(:, :, 3), neighborhoodSize);

% Recombine the filtered channels into one RGB image
filteredImage = cat(3, redChannelFiltered, greenChannelFiltered, blueChannelFiltered);

% Apply Gaussian smoothing
% '1' is the deviation of the Gaussian distribution
filteredImageMedGau = imgaussfilt(filteredImage, 1); 

end

function circleCenters = findCircles(image)

% Convert to grayscale
grayImage = rgb2gray(image);

% Apply threshold to get binary image for circle detection
binaryImage = imbinarize(grayImage);
% Invert to get black circles as white
binaryImage = ~binaryImage;

% Define the radius range, as the images are known is possible to set the
% values
minRadius = 20;
maxRadius = 40;

% Find circles using imfindcircles that uses the Hough Transform to detect
% the circle shapes
[centers, radii, metric] = imfindcircles(binaryImage, [minRadius maxRadius], 'ObjectPolarity','bright', 'Sensitivity',0.92);

% Keep only the four strongest detections based on metric value
numCircles = 4; % number of circles I want to keep
if length(metric) > numCircles
    [~, idx] = maxk(metric, numCircles);
    centers = centers(idx, :);
end

% Sort the black circles coordinates

% 'centers' contains circle centers

% First, sort by y-coordinate to separate top from bottom
[sortedY, orderY] = sort(centers(:, 2), 'ascend');
sortedCentersY = centers(orderY, :);

% Now top circles as the first two entries and the bottom circles as the last two
% Next, sort each of these pairs by their x-coordinate to separate left from right

% For the top two circles
[topSortedX, topOrderX] = sort(sortedCentersY(1:2, 1), 'ascend');
topCircles = sortedCentersY(topOrderX, :);

% For the bottom two circles
[bottomSortedX, bottomOrderX] = sort(sortedCentersY(3:4, 1), 'ascend');
bottomCircles = sortedCentersY(2 + bottomOrderX, :);

% Now concatenate the top and bottom circles to get the final sorted list
% The first row is top-left, second is top-right, third is bottom-left, and fourth is bottom-right
circleCenters = [topCircles; bottomCircles];

end

function imageRotated = correctImage(circleCoordinates, originalImage)

% Rotate the image

% Circles coordinates
x1 = circleCoordinates(1);
y1 = circleCoordinates(5);

x2 = circleCoordinates(2);
y2 = circleCoordinates(6);

% Coordinates of the two top circles in the original image that should be horizontally aligned
circle1 = [x1, y1];
circle2 = [x2, y2];

% Calculate the angle with respect to the horizontal axis
dx = circle2(1) - circle1(1);
dy = circle2(2) - circle1(2);
% The negative sign is to correct the y-axis direction
angle_to_horizontal = atan2(-dy, dx); 

% Convert the angle to degrees
angle_degrees = rad2deg(angle_to_horizontal);

% Rotate the image to align it horizontally
imageRotated = imrotate(originalImage, -angle_degrees, 'bilinear', 'crop');

end

function colors = getColors(imageFiltered)

% Detect the grid

% Convert the filtered image from RGB to HSV color space
hsvImage = rgb2hsv(imageFiltered);

% Define the color thresholds for red, blue, green, yellow, and white in HSV space

% for red
redMask1 = (hsvImage(:,:,1) >= 0.0 & hsvImage(:,:,1) <= 0.1) & (hsvImage(:,:,2) > 0.6) & (hsvImage(:,:,3) > 0.5);
redMask2 = (hsvImage(:,:,1) >= 0.9 & hsvImage(:,:,1) <= 1.0) & (hsvImage(:,:,2) > 0.6) & (hsvImage(:,:,3) > 0.5);
redMask = redMask1 | redMask2;

% For blue
blueMask = (hsvImage(:,:,1) >= 0.55 & hsvImage(:,:,1) <= 0.75) & (hsvImage(:,:,2) > 0.6) & (hsvImage(:,:,3) > 0.5);

% For green
greenMask = (hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.4) & (hsvImage(:,:,2) > 0.7) & (hsvImage(:,:,3) > 0.5);

%For yellow
yellowMask = (hsvImage(:,:,1) > 0.1 & hsvImage(:,:,1) < 0.22) & (hsvImage(:,:,2) > 0.6) & (hsvImage(:,:,3) > 0.5);

% For white
whiteMask = (hsvImage(:,:,2) <= 0.5) & (hsvImage(:,:,3) >= 0.5);

% For purple
purpleMask = (hsvImage(:,:,1) >= 0.65 & hsvImage(:,:,1) <= 0.8) & (hsvImage(:,:,2) > 0.4) & (hsvImage(:,:,3) > 0.4);

% Combine masks for multi-color detection
combinedMask = redMask | blueMask | greenMask | yellowMask | whiteMask | purpleMask;

% Perform morphological operations to clean up the mask
% Remove small objects from the foreground based on the structuring element
cleanedCombinedMask = imopen(combinedMask, strel('disk', 5));

% Label connected components on the combined color mask
[labeledImage, numSquares] = bwlabel(cleanedCombinedMask);

% % Display original image
% figure;
% imshow(imageFiltered)
% title("Filtered image")
% hold on;
% 
% % Measure properties of image regions
% squareMeasurements = regionprops(labeledImage, 'Area', 'BoundingBox', 'Centroid');
% 
% % Loop through all squares and only process those with areas between 5900 and 6100
% for k = 1 : numSquares
%     % Check if the area of the square is within the specified range
%     if squareMeasurements(k).Area > 5800 && squareMeasurements(k).Area < 6200
%         thisBlobsBoundingBox = squareMeasurements(k).BoundingBox;
%         thisBlobCentroid = squareMeasurements(k).Centroid;
% 
%         % Draw a rectangle around the detected color
%         rectangle('Position', thisBlobsBoundingBox, 'EdgeColor', 'w', 'LineWidth', 2);
% 
%         % Mark the centroids
%         plot(thisBlobCentroid(1), thisBlobCentroid(2), 'k+');
% 
%         % % Print the position of the centroid
%         % fprintf('Square #%d (color detected) is at position: x=%.1f, y=%.1f\n', ...
%         %     k, thisBlobCentroid(1), thisBlobCentroid(2));
%     end
% end
% 
% hold off;

%% Get the squares

% Measure properties of image regions
squareMeasurementsExtraction = regionprops(labeledImage, 'Area', 'BoundingBox', 'Centroid');

% Initialize a new struct to store filtered square measurements
squareMeasurementsFiltered = struct('Area', {}, 'BoundingBox', {}, 'Centroid', {});

% Loop through all squares and filter by area
for k = 1 : numSquares
    % Check if the area of the square is within the range of the colored
    % squares
    if squareMeasurementsExtraction(k).Area > 5800 && squareMeasurementsExtraction(k).Area < 6200
        % Extract the bounding box of each square
        squareBoundingBox = floor(squareMeasurementsExtraction(k).BoundingBox);

        % Append the current square's measurements to the new struct if they meet the area criteria
        currentMeasurement = struct(...
            'Area', squareMeasurementsExtraction(k).Area, ...
            'BoundingBox', squareBoundingBox, ...
            'Centroid', squareMeasurementsExtraction(k).Centroid ...
        );
        squareMeasurementsFiltered(end + 1) = currentMeasurement;
    end
end

% Display the filtered measurements
% disp(squareMeasurementsFiltered);

%% Process the squareMeasurementsExtraction

% Extract centroids
centroids = vertcat(squareMeasurementsFiltered.Centroid);

% Truncate the decimal part of each centroid coordinate
truncatedCentroids = floor(centroids);

% Sort the truncated centroids by x and then y
[~, sortedIndices] = sortrows(truncatedCentroids, [1, 2]);

% Reorder the struct array based on sorted indices
sortedSquareMeasurementsFiltered = squareMeasurementsFiltered(sortedIndices);

% % Display the sorted centroids
% for i = 1:length(sortedSquareMeasurementsFiltered)
%     disp(sortedSquareMeasurementsFiltered(i).Centroid);
% end

% Initialize a cell array to store the extracted squares
extractedSquares = {};

% Loop through all squares and extract them from the original image
for k = 1 : length(sortedSquareMeasurementsFiltered)
    % Check if the area of the square is within the specified range

    % Extract the bounding box of each square
    squareBoundingBox = floor(sortedSquareMeasurementsFiltered(k).BoundingBox);

    % Extract the coordinates and dimensions
    x = squareBoundingBox(1);
    y = squareBoundingBox(2);
    width = squareBoundingBox(3);
    height = squareBoundingBox(4);

    % Extract the region from the original image using the bounding box
    extractedSquare = imcrop(imageFiltered, [x, y, width, height]);

    % Store the extracted square in the cell array
    extractedSquares{end + 1} = extractedSquare;

end

%% Detect the colors of the squares

% Initialize a 4x4 cell array to store the colors
colorsMatrix = cell(4, 4);

% Define LAB color centers for matching
colors = struct();

colors.red = [50, 70, 50];        % LAB for Red
colors.green = [50, -50, 50];     % LAB for Green
colors.blue = [50, 20, -50];      % LAB for Blue
colors.yellow = [80, 0, 80];      % LAB for Yellow
colors.white = [100, 0, 0];       % LAB for White
% colors.purple = [55, 50, -40];  % Added range for purple

% Loop through the squares and compare the mean LAB value
for k = 1:length(extractedSquares)

    % Get the current square image
    currentSquare = extractedSquares{k};  
    % Convert the current square from RGB to LAB
    labSquare = rgb2lab(currentSquare);   
    % Calculate the mean LAB color of the square
    meanLAB = squeeze(mean(mean(labSquare, 1), 2)); 

    % Find the closest color
    detectedColorName = '';
    smallestDistance = inf;
    colorNames = fieldnames(colors);
    for c = 1:length(colorNames)
        colorName = colorNames{c};
        colorValue = colors.(colorName);
        distance = sqrt((meanLAB(1) - colorValue(1))^2 + (meanLAB(2) - colorValue(2))^2 + (meanLAB(3) - colorValue(3))^2);

        if distance < smallestDistance
            smallestDistance = distance;
            detectedColorName = colorName;
        end
    end

    % Calculate the correct row and column in the 4x4 matrix for column-major order
    % Adjusting index to start from 0 for proper calculation
    index = k - 1;  
    % Calculate column by dividing the adjusted index by 4
    col = ceil((index + 1) / 4);  
    % Calculate row using modulus to cycle through 1 to 4
    row = mod(index, 4) + 1;  
    % Store the detected color in the result matrix
    colorsMatrix{row, col} = detectedColorName;  
end

colors = colorsMatrix;

end








