# BrainVision BVRF Reader – MATLAB/EEGLAB Plugin

This plugin lets you import BrainVision Recording Format (BVRF) datasets into MATLAB and EEGLAB. It supports the full BVRF 1.0.0 file set:

- Header: `*.bvrh` 
- Data: `*.bvrd` 
- Marker: `*.bvrm` 
- Impedance: `*.bvri` 

The plugin reads the header, data, markers and impedances, and creates one EEGLAB `EEG` structure per participant.

## Files and functions provided

The plugin consists of three main functions:

1. **`eegplugin_bvrfimport`**  
   EEGLAB plugin entry point. Adds a menu item to EEGLAB:
   > *File → Import data → From BrainVision (BVRF)...*

2. **`pop_loadbvrf`**  
   EEGLAB “pop_” function with GUI and history support.

3. **`eeg_loadbvrf`**  
   Low-level loader: reads BVRF files and returns EEGLAB `EEG` structs.


## Installation

### EEGLAB
1. Copy the plugin folder into your EEGLAB `plugins` directory:
   ```
   eeglab/plugins/bvrfimport/
   ```
2. Start or restart EEGLAB.
3. You should now see a menu entry:  
   **File → Import data → From BrainVision (BVRF)...**

### MATLAB
  Do not need installation. Use the function eeg_loadbvrf directly.


## 1. Using the EEGLAB GUI

### Menu location

> **File → Import data → From BrainVision (BVRF)...**

This opens the BVRF Reader GUI included with the plugin.

### BVRF Reader GUI

The GUI shows:

- Dataset information (BVRF version, data type, sample count, sampling rate)
- Participant list with channel counts
- Options for:
  - Single or multi-participant import
  - Sample interval import (samples or seconds)
  - Channel index selection
  - Marker and impedance import
  - Apply sensor calibration if coefficients are present.

![image](docs/bvrf_ui_1.png)


## 2. Using `pop_loadbvrf` (with GUI or scripting)

### Syntax

```matlab
[ALLEEG, com] = pop_loadbvrf(hdrPath, hdrFileName, 'key', value, ...);
[ALLEEG, com] = pop_loadbvrf;  % launches GUI
```

### Optional parameters

| Parameter | Description |
|----------|-------------|
| `sampleInterval` | `[first last]` sample indices (1‑based). Empty = full dataset. |
| `channelIndx` | Vector of channel indices. Empty = all. |
| `flagImportMarkers` | `true`/`false` (default true). |
| `flagImportImpedances` | `true`/`false` (default false). |
| `participantId` | Import only this participant. |
| `usePoly` | `true`/`false` (default: true). Use channels coefficients to calibrate sensor measurements.  |

### Example

```matlab
[ALLEEG, com] = pop_loadbvrf('/data/', 'rec.bvrh', ...
    'sampleInterval', [0 100000], ...
    'channelIndx', 1:32, ...
    'flagImportMarkers', true);
```

## 3. Using `eeg_loadbvrf` directly (low-level loader)

### Syntax

```matlab
[hdr, ALLEEG] = eeg_loadbvrf(hdrPath, hdrFileName, 'key', value, ...);
```

### Example

```matlab
[hdr, ALLEEG] = eeg_loadbvrf('/data/', 'rec.bvrh', ...
    'sampleInterval', [0 600000], ...
    'flagImportMarkers', true, ...
    'verbose', true);
```

## How BVRF fields map to EEGLAB

- **Sampling rate** → `EEG.srate`
- **Data** (from `*.bvrd`) → `EEG.data`
- **Channels** → `EEG.chanlocs` (coordinates extracted when available)
- **Reference** computed from channel `Composition.Minus`
- **Markers** → mapped to `EEG.event`
- **Impedances** → stored in `EEG.etc.impedances`
- **Full header** → stored in `EEG.etc.bvrf_header`

### Importing BVRF Markers to EEGLAB event structure
The BVRF file contains a detailed information of the markers (events) that can not be match to the standard three-structure-fields of the EEG structure in EEGLAB. For this reason, in adition to populating these three fields (type, latemncy and comment) we included most of the native BVRF marker information in the folowing fields:
 
| EEGLAB (EEG.event.) | BVRF | Description|
|-------------------|------|------------|
|bv_type| Type|BV Marker type|
|bv_code| Code |Marker code (e.g., R or S for response or stimulus respectively)|
|bv_value|Value|Marker value to differentiate markers with the same code|
|bv_StartEndId|StartEndId|GUID to identify start-end marker pairs|
|bv_channel|Channel|Channels where the Marker was assigned to. An empty value indicate the marker correspond all the channels|

    events(k).bv_type        = bvtypeStr;
    events(k).bv_code        = safe_get(mk, 'Code', '');
    events(k).bv_value       = safe_get(mk, 'Value', '');
    events(k).bv_StartEndId  = safe_get(mk, 'StartEndId', '');
    events(k).bv_channel     = safe_get(mk, 'Channel', '');


## Known limitations

- Importing fiducials coordinates is not supported currently
- Create post processing function to re-evaluete the sensors data given a new set of coefficients.

## License
MIT

