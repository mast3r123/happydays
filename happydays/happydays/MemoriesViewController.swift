//
//  MemoriesViewController.swift
//  happydays
//
//  Created by master on 1/6/22.
//

import UIKit
import AVFoundation
import Photos
import Speech

class MemoriesViewController: UICollectionViewController {
    
    var memories = [URL]()

    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermissions()
        loadMemories()
    }
    
    func loadMemories() {
        memories.removeAll()
        
        //load all memories in document directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: []) else { return }
        
        //loop over everyfile found
        for file in files {
            let fileName = file.lastPathComponent
            
            if fileName.hasSuffix(".thumb") {
                //get room name of memory
                let noExtension = fileName.replacingOccurrences(of: ".thumb", with: "")
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)
                memories.append(memoryPath)
            }
        }
        collectionView.reloadSections(IndexSet(integer: 1))
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func checkPermissions() {
        let photoAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        let authorized = photoAuthorized && recordingAuthorized && transcribeAuthorized
        
        if !authorized {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(vc, animated: true, completion: nil)
            }
        }
    }
}
