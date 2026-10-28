# Energy Management and Wakeup for IoT Networks Powered by Energy Harvesting
====================================================================================================

This code package is related to the following scientific article:

Ruíz-Guirola, D. E., López, O. L., Montejo-Sánchez, S., Mayorga, I. L., Han, Z., & Popovski, P. (2026, Feb). Energy Management and Wakeup for IoT Networks Powered by Energy Harvesting. In 2026, IoT Journal (pp. 18574 - 18591). IEEE.

Available at: https://arxiv.org/pdf/2508.13825

## Abstract of Article

The rapid growth of the Internet of Things (IoT) presents sustainability challenges, including increased maintenance requirements and overall higher energy consumption. This motivates self-sustainable IoT ecosystems based on energy harvesting (EH). This article treats IoT deployments in which IoT devices (IoTDs) rely solely on EH to sense and transmit information about events/alarms to a base station (BS). The objective is to effectively manage the duty cycling of IoTDs to prolong battery life and maximize the relevant data delivered to the BS. The BS can also selectively wake up specific IoTDs to gather extra information following initial detection. We propose a K-nearest neighbors (KNN)-based duty-cycling management to optimize energy efficiency and detection accuracy by considering spatial correlations among IoTDs’ activity and their EH process. We evaluate machine learning (ML) approaches, including reinforcement learning (RL) and decision transformers (DTs), to maximize information captured from events while managing energy consumption. All three approaches (KNN, RL, and DT) achieve significant energy savings over state-of-the-art methods. Moreover, as the number of IoTDs increases, the RL-based solution approaches the performance of a genie-aided benchmark.

## Content of Code Package

The repository contains MATLAB scripts and user-defined functions needed to reproduce the article's numerical results. 

We recommend the use of high-performance computing services, as these may take hours, if not days, to complete on a normal computer. 

See each file for further documentation. EH_IoT file contains the main code, while the used functions are in the rest.

Check the file README_EH_IoT_Code_Guide.md for more details.

## Acknowledgements

This work has been partially supported by the Research Council of Finland (Grant 369116 (6G Flagship Programme), Grant 362782), the Finnish Foundation for Technology Promotion, the European Commission through the Horizon Europe/JU SNS projects Hexa-X-II (Grant Agreement no. 101095759) and AMBIENT-6G (Grant 101192113), and in Chile, by ANID FONDECYT Regular No.1241977.

## License and Referencing

This code package is licensed under the MIT license. If you use this code in any way for research that results in publications, please cite our original article listed above.
