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

class MemoriesViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    var memories = [URL]()
    var activeMemory: URL!
    
    var audioRecorder: AVAudioRecorder!
    var recordingUrl: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkPermissions()
        loadMemories()
        
        recordingUrl = getDocumentsDirectory().appendingPathExtension("recording.m4a")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
    }
    
    @objc func addTapped() {
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true, completion: nil)
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
    
    func saveNewMemory(image: UIImage) {
        //create memory name
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        let imageName = memoryName + ".jpeg"
        let thumbName = memoryName + ".thumb"
        
        do {
            // create a URL where we can write the JPEG to
            let imagePath =
            getDocumentsDirectory().appendingPathComponent(imageName)
            // convert the UIImage into a JPEG data object
            if let jpegData = image.jpegData(compressionQuality: 0.8)
            {
                // write that data to the URL we created
                try jpegData.write(to: imagePath, options:
                                    [.atomicWrite])
            }
            // create thumbnail
            if let thumb = resize(image: image, to: 200) {
                let imagePath = getDocumentsDirectory().appendingPathComponent(thumbName)
                if let jpegData = thumb.jpegData(compressionQuality: 0.8) {
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
        } catch {
            print("Failed to save to disk.")
        }
    }
    
    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        //calculate scale for resize
        let scale = width / image.size.width
        
        let height = image.size.height * scale
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        return newImage
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
    
    @objc func memoryLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let cell = sender.view as! MemoryCell
            
            if let index = collectionView.indexPath(for: cell) {
                activeMemory = memories[index.row]
                recordMemory()
            }
        } else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    func recordMemory() {
        collectionView.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try? AVAudioRecorder(url: recordingUrl, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
            
        } catch {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        collectionView.backgroundColor = UIColor.darkGray
        
        audioRecorder.stop()
        if success {
            
            do {
                let audioMemoryURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                
                if fm.fileExists(atPath: audioMemoryURL.path) {
                    try fm.removeItem(atPath: audioMemoryURL.path)
                }
                
                try fm.moveItem(at: recordingUrl, to: audioMemoryURL)
                transcribeAudio(memory: activeMemory)
            } catch {
                
            }
            
        }
    }
    
    func transcribeAudio(memory: URL) {
        
    }
}

extension MemoriesViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        
        if let possibleImage = info[.originalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
}

extension MemoriesViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return 0 } else { return memories.count }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as? MemoryCell else { return UICollectionViewCell() }
        let memory = memories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path
        let image = UIImage(contentsOfFile: imageName)
        cell.imageView.image = image
        
        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        
        return cell
    }
    
    //Search bar supplementry view
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if (section == 1)  { return CGSize.zero } else { return CGSize(width: 0, height: 50) }
    }
}

extension MemoriesViewController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
}

extension MemoriesViewController {
    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpeg")
    }
    
    func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    func transcriptURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }
}
