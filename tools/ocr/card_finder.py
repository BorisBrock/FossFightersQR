"""Finds the card in a photo and straightens it, so the text areas can be read at fixed positions on the card.

The card is found as the rectangle of straight edges that best matches the card's aspect ratio: Hough lines
near vertical and near horizontal are combined into candidate rectangles, and each candidate is judged by how
much of its outline lies on edges of the photo."""

import cv2
import numpy as np

ASPECT = 63 / 88  # width / height of a standard playing card
_WORK_SIZE = 1000  # the search runs on a copy of the photo scaled to this longest side
_MAX_TILT = np.radians(12)
_MAX_ASPECT_ERROR = 0.06
_MIN_SUPPORT = 0.5  # fraction of each side of the outline that must lie on an edge


def _lines(edges, vertical, count=12):
    """The strongest straight lines near one orientation as (a, b): x = a + b*y for vertical lines,
    y = a + b*x for horizontal ones. HoughLines (unlike HoughLinesP) sums the votes along the whole line,
    so a card edge that is broken up by a light background is still found."""
    h, w = edges.shape
    if vertical:
        found = cv2.HoughLines(edges, 1, np.pi / 360, int(0.2 * min(h, w)))
    else:
        found = cv2.HoughLines(edges, 1, np.pi / 360, int(0.2 * min(h, w)),
                               min_theta=np.pi / 2 - _MAX_TILT, max_theta=np.pi / 2 + _MAX_TILT)
    lines = []
    for rho, theta in ([] if found is None else found.reshape(-1, 2)):
        if vertical:
            if theta > np.pi / 2:
                rho, theta = -rho, theta - np.pi
            if abs(theta) > _MAX_TILT:
                continue
            a, b = rho / np.cos(theta), -np.tan(theta)
        else:
            a, b = rho / np.sin(theta), -np.cos(theta) / np.sin(theta)
        # the lines come sorted by votes, so a near duplicate of a line already taken is the weaker one
        if all(abs(a - a2) > 4 or abs(b - b2) > 0.03 for a2, b2 in lines):
            lines.append((a, b))
            if len(lines) == count:
                break
    return sorted(lines)


def _corner(vertical, horizontal):
    a, b = vertical
    c, d = horizontal
    y = (c + d * a) / (1 - b * d)
    return a + b * y, y


def find_card(image):
    """Corners of the card (top left, top right, bottom right, bottom left) in pixels of the image, or None."""
    scale = _WORK_SIZE / max(image.shape[:2])
    small = cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    grey = cv2.GaussianBlur(cv2.cvtColor(small, cv2.COLOR_BGR2GRAY), (5, 5), 0)
    edges = cv2.Canny(grey, 30, 90)
    h, w = edges.shape
    near_edge = cv2.dilate(edges, np.ones((5, 5), np.uint8)) > 0
    along = np.linspace(0.12, 0.88, 150)  # leaves out the rounded corners

    def support(p, q):
        x = (p[0] + (q[0] - p[0]) * along).astype(int)
        y = (p[1] + (q[1] - p[1]) * along).astype(int)
        inside = (x >= 0) & (x < w) & (y >= 0) & (y < h)
        return (inside & near_edge[y.clip(0, h - 1), x.clip(0, w - 1)]).mean()

    verticals, horizontals = _lines(edges, True), _lines(edges, False)
    best_score, best = 0, None
    for i, left in enumerate(verticals):
        for right in verticals[i + 1:]:
            for j, top in enumerate(horizontals):
                for bottom in horizontals[j + 1:]:
                    quad = [_corner(left, top), _corner(right, top), _corner(right, bottom), _corner(left, bottom)]
                    width = (quad[1][0] - quad[0][0] + quad[2][0] - quad[3][0]) / 2
                    height = (quad[3][1] - quad[0][1] + quad[2][1] - quad[1][1]) / 2
                    if width < 0.15 * w or height < 0.15 * h:
                        continue
                    aspect_error = abs(width / height / ASPECT - 1)
                    if aspect_error > _MAX_ASPECT_ERROR:
                        continue
                    outline = min(support(quad[k], quad[(k + 1) % 4]) for k in range(4))
                    if outline < _MIN_SUPPORT:
                        continue
                    # the largest well supported rectangle is the card rather than a frame printed on it
                    score = outline * width * height * (1 - aspect_error / _MAX_ASPECT_ERROR)
                    if score > best_score:
                        best_score, best = score, quad
    return None if best is None else np.array(best, np.float32) / scale


def straighten(image, corners, width):
    """The card cut out of the image and warped to an upright rectangle of the given width."""
    height = round(width / ASPECT)
    target = np.float32([[0, 0], [width, 0], [width, height], [0, height]])
    matrix = cv2.getPerspectiveTransform(np.float32(corners), target)
    return cv2.warpPerspective(image, matrix, (width, height), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
