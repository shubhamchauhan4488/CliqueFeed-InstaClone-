//
//  PostViewController.swift
//  CliqueFeed
//
//  Created by SHUBHAM  CHAUHAN on 23/03/18.
//  Copyright © 2018 shubhamchauhan. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import CoreLocation
import Fusuma

class PostViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate, FusumaDelegate {
    
    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var commentField: UITextField!
    @IBOutlet weak var locationField: UITextField!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    let picker = UIImagePickerController()
    var feedStorage : StorageReference!
    var databaseRef : DatabaseReference!
    let userId =  Auth.auth().currentUser?.uid
    var locManager = CLLocationManager()
    var currentLocation : CLLocation!
    var postInfo = [String : Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        commentField.text = ""
        locationField.text = ""
        
        locManager = CLLocationManager()
        locManager.delegate = self
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.requestWhenInUseAuthorization()
        locManager.startUpdatingLocation()
        
        picker.delegate = self
        let storage = Storage.storage().reference(forURL: "gs://cliquefeed-48d9c.appspot.com")
        feedStorage = storage.child("feed")
        databaseRef = Database.database().reference()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        postImage.isUserInteractionEnabled = true
        postImage.addGestureRecognizer(tapGestureRecognizer)
        saveButton.isEnabled = true
    }
    
    //Calling instagram-like 3rd party library to add/capture image
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode) {
        
        print(image)
        self.postImage.image = image
        
        if let lastLocation = self.currentLocation {
            let geocoder = CLGeocoder()
            
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation,completionHandler: { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    self.locationField.text = (firstLocation?.name)! + "," + (firstLocation?.locality)! + "," + (firstLocation?.country)!
                }
                else {
                    // An error occurred during geocoding.
                    print("error while geocoding")
                }
            })
        }else{
            let alert = UIAlertController(title: "Error", message: "Couldn't fetch Location", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true)
        }
    }
    
    func fusumaMultipleImageSelected(_ images: [UIImage], source: FusumaMode) {
    }
    
    func fusumaVideoCompleted(withFileURL fileURL: URL) {
    }
    
    func fusumaCameraRollUnauthorized() {
    }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        let fusuma = FusumaViewController()
        fusuma.delegate = self
        //fusuma.hasVideo = true //To allow for video capturing with .library and .camera available by default
        fusuma.cropHeightRatio = 1 // Height-to-width ratio. The default value is 1, which means a squared-size photo.
        //fusuma.allowMultipleSelection = true // You can select multiple photos from the camera roll. The default value is false.
        self.present(fusuma, animated: true, completion: nil)
    }
    
    
    
    //    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    //
    //        //Getting the image from info and storing in postImage.image
    //        if let image = info[UIImagePickerControllerEditedImage] as? UIImage
    //        {
    //            self.postImage.image = image
    //        }
    //
    //        if let lastLocation = self.currentLocation {
    //
    //            let geocoder = CLGeocoder()
    //
    //            // Look up the location and pass it to the completion handler to get the detailed Placemark
    //            geocoder.reverseGeocodeLocation(lastLocation,completionHandler: { (placemarks, error) in
    //                if error == nil {
    //                    let firstLocation = placemarks?[0]
    //                    self.locationField.text = (firstLocation?.name)! + "," + (firstLocation?.locality)! + "," + (firstLocation?.country)!
    //                }
    //                else {
    //                    // An error occurred during geocoding.
    //                    print("error while geocoding")
    //                }
    //            })
    //        }
    //        self.dismiss(animated: true, completion: nil)
    //    }
    
    
    //MARK :- On Save click
    @IBAction func onPost(_ sender: Any) {
        
        //Checking whether all the info is entered by the user, to prevent bogus/irrelevant posts
        if(self.postImage.image != UIImage(named: "cam") && self.commentField.text != "" && self.locationField.text != ""){
            
            //Disabling the Save btn while saving to Firebase
            saveButton.isEnabled = false
            let imageRef = self.feedStorage.child(userId!).child("\(userId! + String(arc4random())).jpg")
            
            //Downgrading the image selected by the user and putting in 'data' variable
            let data = UIImageJPEGRepresentation(self.postImage.image!, 0.5 )
            
            //Putting the image on the 'unique' reference created on Firebase inside Users folder
            let uploadTask = imageRef.putData(data!, metadata: nil, completion: { (metadata, err) in
                if let err = err {
                    print("Image Upload task Error : ", err.localizedDescription)
                }
                
                //Image was uploaded successfully, getting the url
                imageRef.downloadURL(completion: { (url, er) in
                    if let er = er {
                        print(er.localizedDescription)
                    }
                    
                    //URL fetch success : Save the post to Firebase
                    if let url = url{
                        self.uploadPostToFirebase(url : url)
                        //Reseting everthing to default values to avoid redundant posts
                        self.postImage.image = UIImage(named : "cam")
                        self.commentField.text = ""
                        self.locationField.text = ""
                        self.saveButton.isEnabled = true
                    }
                })
            })
            uploadTask.resume()
        }
        else{
            let alert = UIAlertController(title: "Incomplete Info for post", message: "No fileds should be left blank", preferredStyle: .actionSheet)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true)
        }
    }
    
    func uploadPostToFirebase(url : URL){
        UIApplication.shared.beginIgnoringInteractionEvents()
        let timeInterval = NSDate().timeIntervalSince1970
        let randomUserID = "LLSADKNNukabwdd27ekbq"
        let likedBy = ["KDSALNjksdLSJNF27B3DF" : randomUserID]
        //Creating postInfo object and saving to Firebase
        self.postInfo  = ["uid": self.userId!,
                          "urlImage": url.absoluteString,
                          "comment" : self.commentField.text!,
                          "comments" : [String](),
                          "latitude" : self.currentLocation.coordinate.latitude,
                          "longitude" : self.currentLocation.coordinate.longitude,
                          "geoTagLocation" : self.locationField.text!,
                          "likes" : 0,
                          "likedBy": likedBy,
                          "timestamp" : timeInterval]
        
        self.databaseRef.child("posts").childByAutoId().setValue(self.postInfo)
        
        //Once the post is successful on FIREBASE, it will trigger the FeedViewController as the data has changed and the feeds tableview will be reloaded automatically
        let alert = UIAlertController(title: "Successfull", message: "Image has been posted", preferredStyle: .actionSheet)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        self.present(alert, animated: true)
        UIApplication.shared.endIgnoringInteractionEvents()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = manager.location  
    }
    
}
